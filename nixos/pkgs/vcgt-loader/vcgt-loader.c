// vcgt-loader: load an ICC profile's calibration curve (the 'vcgt' tag) into
// the display's gamma table through wlr-gamma-control -- what Windows does
// with a monitor profile -- without the compositor's ICC colour conversion.
//
// Usage: vcgt-loader PROFILE.icc [OUTPUT-DESCRIPTION-SUBSTRING]
// Stays running: the compositor drops the curve when this client exits.
#define _GNU_SOURCE
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-gamma-control-unstable-v1-client-protocol.h"

static double curve[3][4096];
static int curve_len;
static const char *match;
static struct zwlr_gamma_control_manager_v1 *manager;

struct output {
    struct wl_output *wl;
    struct zwlr_gamma_control_v1 *gamma;
    char desc[256];
    struct output *next;
};
static struct output *outputs;

static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }
static uint16_t be16(const uint8_t *p) { return (uint16_t)(p[0] << 8 | p[1]); }

static void load_vcgt(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }
    static uint8_t d[1 << 22];
    size_t n = fread(d, 1, sizeof d, f);
    fclose(f);
    if (n < 132) { fprintf(stderr, "%s: not an ICC profile\n", path); exit(1); }
    uint32_t count = be32(d + 128);
    for (uint32_t i = 0; i < count && 144 + 12 * i <= n; i++) {
        const uint8_t *t = d + 132 + 12 * i;
        if (memcmp(t, "vcgt", 4)) continue;
        uint32_t off = be32(t + 4), len = be32(t + 8);
        if (off + len > n || len < 18) break;
        const uint8_t *v = d + off;
        if (be32(v + 8) == 0) {  // table form
            int ch = be16(v + 12), cnt = be16(v + 14), sz = be16(v + 16);
            if ((ch != 1 && ch != 3) || cnt < 2 || cnt > 4096 || (sz != 1 && sz != 2) ||
                18 + (size_t)ch * cnt * sz > len) break;
            curve_len = cnt;
            for (int c = 0; c < 3; c++)
                for (int k = 0; k < cnt; k++) {
                    const uint8_t *e = v + 18 + ((size_t)(ch == 1 ? 0 : c) * cnt + k) * sz;
                    curve[c][k] = sz == 2 ? be16(e) / 65535.0 : e[0] / 255.0;
                }
            return;
        }
        if (be32(v + 8) == 1 && len >= 12 + 36) {  // formula form: gamma, min, max
            curve_len = 256;
            for (int c = 0; c < 3; c++) {
                const uint8_t *e = v + 12 + 12 * c;
                double g = be32(e) / 65536.0, lo = be32(e + 4) / 65536.0, hi = be32(e + 8) / 65536.0;
                for (int k = 0; k < 256; k++) {
                    curve[c][k] = lo + (hi - lo) * pow(k / 255.0, g);
                }
            }
            return;
        }
        break;
    }
    fprintf(stderr, "%s: no usable vcgt calibration curve\n", path);
    exit(1);
}

static double sample(int c, double x) {  // linear interpolation, x in [0,1]
    double p = x * (curve_len - 1);
    int i = (int)p;
    if (i >= curve_len - 1) return curve[c][curve_len - 1];
    return curve[c][i] + (curve[c][i + 1] - curve[c][i]) * (p - i);
}

static void gamma_size(void *data, struct zwlr_gamma_control_v1 *g, uint32_t size) {
    struct output *o = data;
    size_t bytes = (size_t)size * 3 * sizeof(uint16_t);
    int fd = memfd_create("vcgt", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, bytes) < 0) { perror("memfd"); exit(1); }
    uint16_t *r = mmap(NULL, bytes, PROT_WRITE, MAP_SHARED, fd, 0);
    if (r == MAP_FAILED) { perror("mmap"); exit(1); }
    for (int c = 0; c < 3; c++)
        for (uint32_t k = 0; k < size; k++)
            r[c * size + k] = (uint16_t)(sample(c, size > 1 ? (double)k / (size - 1) : 0) * 65535.0 + 0.5);
    munmap(r, bytes);
    zwlr_gamma_control_v1_set_gamma(g, fd);
    close(fd);
    fprintf(stderr, "vcgt-loader: curve set on %s (%u entries)\n", o->desc, size);
}

static void gamma_failed(void *data, struct zwlr_gamma_control_v1 *g) {
    struct output *o = data;
    fprintf(stderr, "vcgt-loader: gamma control refused for %s (another program holds it?)\n", o->desc);
    zwlr_gamma_control_v1_destroy(g);
    o->gamma = NULL;
}

static const struct zwlr_gamma_control_v1_listener gamma_listener = { gamma_size, gamma_failed };

static void out_geometry(void *d, struct wl_output *w, int32_t x, int32_t y, int32_t pw, int32_t ph,
                         int32_t sp, const char *make, const char *model, int32_t tr) {}
static void out_mode(void *d, struct wl_output *w, uint32_t f, int32_t wd, int32_t h, int32_t r) {}
static void out_scale(void *d, struct wl_output *w, int32_t s) {}
static void out_name(void *d, struct wl_output *w, const char *name) {}
static void out_description(void *data, struct wl_output *w, const char *desc) {
    struct output *o = data;
    snprintf(o->desc, sizeof o->desc, "%s", desc);
}
static void out_done(void *data, struct wl_output *w) {
    struct output *o = data;
    if (o->gamma || !manager) return;
    if (match && !strstr(o->desc, match)) return;
    o->gamma = zwlr_gamma_control_manager_v1_get_gamma_control(manager, o->wl);
    zwlr_gamma_control_v1_add_listener(o->gamma, &gamma_listener, o);
}
static const struct wl_output_listener output_listener = {
    out_geometry, out_mode, out_done, out_scale, out_name, out_description,
};

static void reg_global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t ver) {
    if (!strcmp(iface, zwlr_gamma_control_manager_v1_interface.name)) {
        manager = wl_registry_bind(reg, name, &zwlr_gamma_control_manager_v1_interface, 1);
    } else if (!strcmp(iface, wl_output_interface.name) && ver >= 4) {
        struct output *o = calloc(1, sizeof *o);
        o->wl = wl_registry_bind(reg, name, &wl_output_interface, 4);
        o->next = outputs;
        outputs = o;
        wl_output_add_listener(o->wl, &output_listener, o);
    }
}
static void reg_remove(void *data, struct wl_registry *reg, uint32_t name) {}
static const struct wl_registry_listener registry_listener = { reg_global, reg_remove };

int main(int argc, char **argv) {
    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s PROFILE.icc [OUTPUT-DESCRIPTION-SUBSTRING]\n", argv[0]);
        return 2;
    }
    load_vcgt(argv[1]);
    match = argc == 3 ? argv[2] : NULL;
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "vcgt-loader: no Wayland display\n"); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &registry_listener, NULL);
    wl_display_roundtrip(dpy);
    if (!manager) { fprintf(stderr, "vcgt-loader: compositor lacks wlr-gamma-control\n"); return 1; }
    // Outputs that were announced before the manager got bound.
    wl_display_roundtrip(dpy);
    for (struct output *o = outputs; o; o = o->next) out_done(o, o->wl);
    while (wl_display_dispatch(dpy) != -1) {}
    return 0;
}
