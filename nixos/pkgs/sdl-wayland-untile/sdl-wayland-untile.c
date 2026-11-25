// LD_PRELOAD shim: hide the xdg_toplevel TILED_* states from the client.
//
// Hyprland marks every toplevel as tiled on all four edges, floating ones
// too. SDL3 (checked 3.4.4 - main) then stops saving programmatic resizes of
// a fixed-size (non-resizable) window (SDL_windowevents.c: floating.w is only
// updated when !window->tiled), and answers each configure with that stale
// saved size. Unreal's autosized dialogs are created at 1x1 and resized to
// fit their content, so they collapse back to 1x1: an empty frame.
//
// SDL loads libwayland-client with dlopen + dlsym, so dlsym is hooked to
// hand out our wl_proxy_add_listener; programs linked directly against
// libwayland get the exported one.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct wl_proxy;
struct wl_array { size_t size, alloc; void *data; };
typedef void (*listener_fn)(void);
typedef void (*configure_fn)(void *, struct wl_proxy *, int32_t, int32_t, struct wl_array *);

enum { TILED_LEFT = 5, TILED_RIGHT = 6, TILED_TOP = 7, TILED_BOTTOM = 8 };
// xdg_toplevel events: configure, close, configure_bounds, wm_capabilities.
#define TOPLEVEL_EVENTS 4
#define MAX_LISTENERS 16

static void *(*real_dlsym)(void *, const char *);
static int (*real_add_listener)(struct wl_proxy *, listener_fn *, void *);
static const char *(*real_get_class)(struct wl_proxy *);
static const void *(*real_get_listener)(struct wl_proxy *);

struct wrapped { listener_fn fns[TOPLEVEL_EVENTS]; const listener_fn *orig; };
static struct wrapped wrapped_listeners[MAX_LISTENERS];
static int n_wrapped;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static void init(void)
{
    real_dlsym = dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
    if (!real_dlsym)
        real_dlsym = dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
}

static int resolve_wayland(void)
{
    if (real_add_listener)
        return 1;
    void *h = dlopen("libwayland-client.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (!h)
        return 0;
    if (!real_dlsym)
        init();
    real_get_class = real_dlsym(h, "wl_proxy_get_class");
    real_get_listener = real_dlsym(h, "wl_proxy_get_listener");
    real_add_listener = real_dlsym(h, "wl_proxy_add_listener");
    return real_add_listener != NULL;
}

static void untiled_configure(void *data, struct wl_proxy *toplevel,
                              int32_t width, int32_t height, struct wl_array *states)
{
    const void *mine = real_get_listener(toplevel);
    const listener_fn *orig = NULL;
    for (int i = 0; i < n_wrapped; i++)
        if (wrapped_listeners[i].fns == mine)
            orig = wrapped_listeners[i].orig;
    if (!orig)
        return;

    uint32_t kept[32];
    struct wl_array filtered = { 0, sizeof(kept), kept };
    uint32_t *s = states->data;
    for (size_t i = 0; i < states->size / sizeof(uint32_t) && filtered.size < sizeof(kept); i++) {
        if (s[i] >= TILED_LEFT && s[i] <= TILED_BOTTOM)
            continue;
        kept[filtered.size / sizeof(uint32_t)] = s[i];
        filtered.size += sizeof(uint32_t);
    }
    ((configure_fn)orig[0])(data, toplevel, width, height, &filtered);
}

int wl_proxy_add_listener(struct wl_proxy *proxy, listener_fn *listener, void *data)
{
    if (!resolve_wayland())
        abort();
    const char *cls = real_get_class ? real_get_class(proxy) : NULL;
    if (!cls || strcmp(cls, "xdg_toplevel") != 0)
        return real_add_listener(proxy, listener, data);

    pthread_mutex_lock(&lock);
    struct wrapped *w = NULL;
    for (int i = 0; i < n_wrapped; i++)
        if (wrapped_listeners[i].orig == listener)
            w = &wrapped_listeners[i];
    if (!w && n_wrapped < MAX_LISTENERS) {
        w = &wrapped_listeners[n_wrapped];
        memcpy(w->fns, listener, sizeof(w->fns));
        w->fns[0] = (listener_fn)untiled_configure;
        w->orig = listener;
        n_wrapped++;
    }
    pthread_mutex_unlock(&lock);
    return real_add_listener(proxy, w ? w->fns : listener, data);
}

// Must stay a tail call: glibc resolves RTLD_NEXT relative to dlsym's
// return address, which then still points into the real caller.
// Initialized lazily: other libraries' constructors (libsystemd) call
// dlsym before ours would run.
void *dlsym(void *handle, const char *name)
{
    if (__builtin_expect(!real_dlsym, 0))
        init();
    if (strcmp(name, "wl_proxy_add_listener") == 0)
        return (void *)wl_proxy_add_listener;
    return real_dlsym(handle, name);
}
