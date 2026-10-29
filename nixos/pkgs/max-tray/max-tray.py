"""Tray icon for the MAX messenger (Flatpak ru.max.MAX), with a red dot
while there are unread messages.

MAX has no tray icon of its own, and its unread badge never leaves the app
(its log says "Cannot set badge number - desktopFileName() is empty"). But it
logs its unread counters, e.g.
  [Ui::CountersContext]setTotalUnreadCounter counter: 2
  [Ui::CountersContext]setCountUnreadUnmutedChats counter: 1
Both leave out muted chats. They come from MAX's server, so they also drop
when messages are read on the phone. This program follows the log file the
running MAX has open and shows a red dot while the total is > 0.

The icon shows only while MAX runs (status "Passive" hides it, see
nixos/overlays/wayle-systray-hide-passive.patch).

Left click: go to the MAX window (switches to its workspace), or start MAX.
Right click: menu with "Open MAX" and "Quit MAX".
The same tray protocol (StatusNotifierItem) as pkgs/whatsapp-tray.
"""

import json
import os
import re
import signal
import socket
import subprocess

from gi.repository import Gio, GLib

CLASS = "max"  # Hyprland window class
FLATPAK_ID = "ru.max.MAX"
LOG_DIR = os.path.expanduser(f"~/.var/app/{FLATPAK_ID}/data/ONEME/logs")
ICON_DIR = os.environ.get("MAX_TRAY_ICONS", os.path.dirname(__file__))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
HYPR = os.path.join(RUNTIME, "hypr",
                    os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))
POLL_SECONDS = 2

COUNTER_RE = re.compile(
    rb"\]set(TotalUnreadCounter|CountUnreadUnmutedChats) counter: (\d+)")

SNI_XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="IconThemePath" type="s" access="read"/>
    <property name="ToolTip" type="(sa(iiay)ss)" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <property name="Menu" type="o" access="read"/>
    <method name="Activate"><arg type="i"/><arg type="i"/></method>
    <method name="SecondaryActivate"><arg type="i"/><arg type="i"/></method>
    <method name="ContextMenu"><arg type="i"/><arg type="i"/></method>
    <method name="Scroll"><arg type="i"/><arg type="s"/></method>
    <signal name="NewIcon"/>
    <signal name="NewToolTip"/>
    <signal name="NewStatus"><arg type="s"/></signal>
  </interface>
</node>"""

MENU_XML = """
<node>
  <interface name="com.canonical.dbusmenu">
    <property name="Version" type="u" access="read"/>
    <property name="TextDirection" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconThemePath" type="as" access="read"/>
    <method name="GetLayout">
      <arg type="i" direction="in"/><arg type="i" direction="in"/>
      <arg type="as" direction="in"/>
      <arg type="u" direction="out"/><arg type="(ia{sv}av)" direction="out"/>
    </method>
    <method name="GetGroupProperties">
      <arg type="ai" direction="in"/><arg type="as" direction="in"/>
      <arg type="a(ia{sv})" direction="out"/>
    </method>
    <method name="GetProperty">
      <arg type="i" direction="in"/><arg type="s" direction="in"/>
      <arg type="v" direction="out"/>
    </method>
    <method name="Event">
      <arg type="i" direction="in"/><arg type="s" direction="in"/>
      <arg type="v" direction="in"/><arg type="u" direction="in"/>
    </method>
    <method name="EventGroup">
      <arg type="a(isvu)" direction="in"/><arg type="ai" direction="out"/>
    </method>
    <method name="AboutToShow">
      <arg type="i" direction="in"/><arg type="b" direction="out"/>
    </method>
    <method name="AboutToShowGroup">
      <arg type="ai" direction="in"/>
      <arg type="ai" direction="out"/><arg type="ai" direction="out"/>
    </method>
    <signal name="LayoutUpdated"><arg type="u"/><arg type="i"/></signal>
    <signal name="ItemsPropertiesUpdated">
      <arg type="a(ia{sv})"/><arg type="a(ias)"/>
    </signal>
  </interface>
</node>"""

SNI_PATH = "/StatusNotifierItem"
MENU_PATH = "/MenuBar"
MENU_ITEMS = {1: "Open MAX", 2: "Quit MAX"}
QUIT_GRACE_SECONDS = 5


def hypr_request(cmd):
    """Ask Hyprland directly over its control socket (what hyprctl does)."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.path.join(HYPR, ".socket.sock"))
        s.sendall(cmd.encode())
        chunks = []
        while chunk := s.recv(65536):
            chunks.append(chunk)
    return b"".join(chunks).decode()


def find_max_pid():
    """PID of the main MAX process, or None. Inside the sandbox it's called
    "max"; its cgroup names the Flatpak app. A second launch briefly starts
    another "max" (it hands over to the first and quits): take the oldest."""
    found = []
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() != "max":
                    continue
            with open(f"/proc/{pid}/cgroup") as f:
                if FLATPAK_ID not in f.read():
                    continue
            with open(f"/proc/{pid}/stat") as f:
                started = int(f.read().rsplit(")", 1)[1].split()[19])
        except (OSError, ValueError, IndexError):
            continue
        found.append((started, int(pid)))
    return min(found)[1] if found else None


def open_log(pid):
    """The log file MAX (pid) is writing to, or None."""
    try:
        fds = os.listdir(f"/proc/{pid}/fd")
    except OSError:
        return None
    for fd in fds:
        try:
            target = os.readlink(f"/proc/{pid}/fd/{fd}")
        except OSError:
            continue
        if target.startswith(LOG_DIR + "/log_"):
            return target
    return None


class Tray:
    def __init__(self):
        self.total = 0     # unread messages (unmuted chats)
        self.chats = 0     # unread unmuted chats
        self.running = False
        self.pid = None
        self.log = None    # path of the log being followed
        self.offset = 0    # bytes of it already read
        self.partial = b""
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION)
        self.bus_name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"

    # --- state -----------------------------------------------------------
    def set_counts(self, total, chats):
        if (total, chats) == (self.total, self.chats):
            return
        had_dot = bool(self.total)
        self.total, self.chats = total, chats
        if bool(total) != had_dot:
            self.emit("NewIcon")
        self.emit("NewToolTip")

    def set_running(self, running):
        if running != self.running:
            self.running = running
            self.emit("NewStatus", GLib.Variant("(s)", (self.status(),)))

    def status(self):
        return "Active" if self.running else "Passive"

    def tooltip(self):
        if self.total == 0:
            text = "No new messages"
        else:
            msgs = "1 new message" if self.total == 1 \
                else f"{self.total} new messages"
            chats = "1 chat" if self.chats == 1 else f"{self.chats} chats"
            text = f"{msgs} in {chats}" if self.chats else msgs
        return GLib.Variant("(sa(iiay)ss)", ("", [], "MAX", text))

    # --- polling MAX's process and log -----------------------------------
    def poll(self):
        if self.pid is None or not os.path.exists(f"/proc/{self.pid}"):
            self.pid = find_max_pid()
        self.set_running(self.pid is not None)
        if self.pid is not None:
            log = open_log(self.pid)
            if log and log != self.log:
                # New MAX session: read its log from the start.
                self.log, self.offset, self.partial = log, 0, b""
            if self.log:
                self.read_log()
        return True  # keep the timer

    def read_log(self):
        try:
            with open(self.log, "rb") as f:
                f.seek(self.offset)
                data = f.read()
        except OSError:
            return
        if not data:
            return
        self.offset += len(data)
        data = self.partial + data
        data, _, self.partial = data.rpartition(b"\n")
        total, chats = self.total, self.chats
        for name, value in COUNTER_RE.findall(data):
            if name == b"TotalUnreadCounter":
                total = int(value)
            else:
                chats = int(value)
        self.set_counts(total, chats)

    def open_max(self):
        clients = json.loads(hypr_request("j/clients"))
        win = next((c for c in clients if c.get("class") == CLASS), None)
        if win:
            subprocess.Popen(["hyprctl", "eval",
                              "hl.dispatch(hl.dsp.focus({ window = "
                              f"'address:{win['address']}' }}))"],
                             stdout=subprocess.DEVNULL)
        else:
            # Through Hyprland, so it opens on the current workspace. If MAX
            # runs without a window, this just brings its window back.
            subprocess.Popen(["hyprctl", "eval",
                              f"hl.exec_cmd('flatpak run {FLATPAK_ID}')"],
                             stdout=subprocess.DEVNULL)

    def quit_max(self):
        """Ask MAX to exit (SIGTERM, like closing it properly), then stop the
        rest of its sandbox: its calls helper (max-service) and crash
        reporters outlive it, and a new launch would hand over to them
        instead of starting. Waits up to a few seconds for MAX itself."""
        pid = find_max_pid()
        if pid is None:
            return
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
        waited = [0]

        def finish():
            waited[0] += 1
            if find_max_pid() is not None and waited[0] < QUIT_GRACE_SECONDS * 4:
                return True  # check again in 0.25 s
            subprocess.Popen(["flatpak", "kill", FLATPAK_ID],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            return False
        GLib.timeout_add(250, finish)

    # --- D-Bus: StatusNotifierItem ---------------------------------------
    def emit(self, signal, params=None):
        self.bus.emit_signal(None, SNI_PATH, "org.kde.StatusNotifierItem",
                             signal, params)

    def sni_get(self, _conn, _sender, _path, _iface, prop):
        icon = "max-unread" if self.total else "max"
        values = {
            "Category": GLib.Variant("s", "Communications"),
            "Id": GLib.Variant("s", "max-tray"),
            "Title": GLib.Variant("s", "MAX"),
            "Status": GLib.Variant("s", self.status()),
            "IconName": GLib.Variant("s", icon),
            "IconThemePath": GLib.Variant("s", ICON_DIR),
            "ToolTip": self.tooltip(),
            "ItemIsMenu": GLib.Variant("b", False),
            "Menu": GLib.Variant("o", MENU_PATH),
        }
        return values.get(prop)

    def sni_call(self, _conn, _sender, _path, _iface, method, _params, inv):
        if method == "Activate":
            self.open_max()
        inv.return_value(None)

    # --- D-Bus: menu (com.canonical.dbusmenu) ----------------------------
    @staticmethod
    def menu_item(item_id):
        props = {"label": GLib.Variant("s", MENU_ITEMS[item_id]),
                 "enabled": GLib.Variant("b", True),
                 "visible": GLib.Variant("b", True)}
        return GLib.Variant("(ia{sv}av)", (item_id, props, []))

    def menu_get(self, _conn, _sender, _path, _iface, prop):
        return {"Version": GLib.Variant("u", 3),
                "TextDirection": GLib.Variant("s", "ltr"),
                "Status": GLib.Variant("s", "normal"),
                "IconThemePath": GLib.Variant("as", [])}.get(prop)

    def menu_call(self, _conn, _sender, _path, _iface, method, params, inv):
        args = params.unpack()
        if method == "GetLayout":
            root = (0, {"children-display": GLib.Variant("s", "submenu")},
                    [self.menu_item(i) for i in MENU_ITEMS])
            inv.return_value(GLib.Variant("(u(ia{sv}av))", (1, root)))
        elif method == "GetGroupProperties":
            ids = args[0] or list(MENU_ITEMS)
            out = [(i, {"label": GLib.Variant("s", MENU_ITEMS[i])})
                   for i in ids if i in MENU_ITEMS]
            inv.return_value(GLib.Variant("(a(ia{sv}))", (out,)))
        elif method == "GetProperty":
            item_id, name = args
            if item_id in MENU_ITEMS and name == "label":
                value = GLib.Variant("s", MENU_ITEMS[item_id])
                inv.return_value(GLib.Variant("(v)", (value,)))
            else:
                inv.return_dbus_error("com.canonical.dbusmenu.Error",
                                      "no such property")
        elif method == "Event":
            item_id, event_id = args[0], args[1]
            if event_id == "clicked":
                self.menu_clicked(item_id)
            inv.return_value(None)
        elif method == "EventGroup":
            for item_id, event_id, _data, _ts in args[0]:
                if event_id == "clicked":
                    self.menu_clicked(item_id)
            inv.return_value(GLib.Variant("(ai)", ([],)))
        elif method == "AboutToShow":
            inv.return_value(GLib.Variant("(b)", (False,)))
        elif method == "AboutToShowGroup":
            inv.return_value(GLib.Variant("(aiai)", ([], [])))

    def menu_clicked(self, item_id):
        if item_id == 1:
            self.open_max()
        elif item_id == 2:
            self.quit_max()

    # --- setup -----------------------------------------------------------
    def export(self):
        sni = Gio.DBusNodeInfo.new_for_xml(SNI_XML).interfaces[0]
        menu = Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0]
        self.bus.register_object(SNI_PATH, sni, self.sni_call,
                                 self.sni_get, None)
        self.bus.register_object(MENU_PATH, menu, self.menu_call,
                                 self.menu_get, None)
        Gio.bus_own_name_on_connection(self.bus, self.bus_name,
                                       Gio.BusNameOwnerFlags.NONE, None, None)
        # (Re-)register whenever a tray host appears, e.g. after the bar
        # restarts.
        Gio.bus_watch_name_on_connection(
            self.bus, "org.kde.StatusNotifierWatcher",
            Gio.BusNameWatcherFlags.NONE, self.register, None)

    def register(self, *_args):
        self.bus.call(
            "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
            "org.kde.StatusNotifierWatcher", "RegisterStatusNotifierItem",
            GLib.Variant("(s)", (self.bus_name,)), None,
            Gio.DBusCallFlags.NONE, -1, None, None)


def main():
    tray = Tray()
    tray.poll()  # before export, so the first state shown is right
    tray.export()
    GLib.timeout_add_seconds(POLL_SECONDS, tray.poll)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
