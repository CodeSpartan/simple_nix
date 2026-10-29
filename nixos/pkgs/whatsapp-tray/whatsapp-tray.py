"""Tray icon for the WhatsApp Brave PWA, with a red dot for new messages.

WhatsApp Web shows no unread count anywhere the desktop can read (the PWA
window title stays "WhatsApp Web", and Brave sends no app badge on Linux).
It does send a desktop notification per message whose body starts with
"web.whatsapp.com". So:
  - WhatsApp notification while its window isn't focused  -> red dot
  - the WhatsApp window gets focus                         -> dot cleared
Messages read on the phone aren't seen; "Mark as read" in the right-click
menu (or middle click) clears the dot.

The icon is a StatusNotifierItem, the same tray protocol Telegram etc. use.
It shows only while the WhatsApp window is open (status "Passive" hides it,
see nixos/overlays/wayle-systray-hide-passive.patch).

Left click: go to the WhatsApp window (switches to its workspace).
"""

import json
import os
import socket
import subprocess
import sys

from gi.repository import Gio, GLib

APP_ID = "hnpfjngllnobngcgfapefoaidbinmjnm"  # from brave-<id>-Default.desktop
CLASS = f"brave-{APP_ID}-Default"
ICON_DIR = os.environ.get("WHATSAPP_TRAY_ICONS", os.path.dirname(__file__))
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
# Survives a restart of this program; cleared at logout (tmpfs).
COUNT_FILE = os.path.join(RUNTIME, "whatsapp-tray-unread")
HYPR = os.path.join(RUNTIME, "hypr",
                    os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", ""))

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
MENU_ITEMS = {1: "Open WhatsApp", 2: "Mark as read"}


def hypr_request(cmd):
    """Ask Hyprland directly over its control socket (what hyprctl does)."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(os.path.join(HYPR, ".socket.sock"))
        s.sendall(cmd.encode())
        chunks = []
        while chunk := s.recv(65536):
            chunks.append(chunk)
    return b"".join(chunks).decode()


def strip0x(addr):
    return addr[2:] if addr.startswith("0x") else addr


class Tray:
    def __init__(self):
        self.count = self.load_count()
        self.window = ""   # WhatsApp window address, no "0x"; "" = not open
        self.focused = ""
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION)
        self.bus_name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"
        self.refresh_windows()

    # --- state -----------------------------------------------------------
    @staticmethod
    def load_count():
        try:
            with open(COUNT_FILE) as f:
                return max(0, int(f.read().strip()))
        except (OSError, ValueError):
            return 0

    def set_count(self, n):
        if n == self.count:
            return
        self.count = n
        try:
            with open(COUNT_FILE, "w") as f:
                f.write(str(n))
        except OSError:
            pass
        self.emit("NewIcon")
        self.emit("NewToolTip")

    def refresh_windows(self):
        clients = json.loads(hypr_request("j/clients"))
        win = next((c for c in clients if c.get("class") == CLASS), None)
        self.set_window(strip0x(win["address"]) if win else "")
        active = json.loads(hypr_request("j/activewindow") or "{}")
        self.focused = strip0x(active.get("address", ""))

    def set_window(self, addr):
        was_open = bool(self.window)
        self.window = addr
        if bool(addr) != was_open:
            self.emit("NewStatus", GLib.Variant("(s)", (self.status(),)))

    def status(self):
        return "Active" if self.window else "Passive"

    def tooltip(self):
        if self.count == 0:
            text = "No new messages"
        elif self.count == 1:
            text = "1 new message"
        else:
            text = f"{self.count} new messages"
        return GLib.Variant("(sa(iiay)ss)", ("", [], "WhatsApp", text))

    # --- events ----------------------------------------------------------
    def on_message(self):
        if not (self.window and self.focused == self.window):
            self.set_count(self.count + 1)

    def on_hypr_event(self, line):
        event, _, data = line.partition(">>")
        if event == "activewindowv2":
            self.focused = data
            if self.window and data == self.window:
                self.set_count(0)
        elif event == "openwindow":
            addr, _, rest = data.partition(",")
            if rest.split(",", 2)[1:2] == [CLASS]:
                self.set_window(addr)
        elif event == "closewindow":
            if data == self.window:
                self.set_window("")

    def open_window(self):
        if self.window:
            subprocess.Popen(["hyprctl", "eval",
                              "hl.dispatch(hl.dsp.focus({ window = "
                              f"'address:0x{self.window}' }}))"],
                             stdout=subprocess.DEVNULL)

    # --- D-Bus: StatusNotifierItem ---------------------------------------
    def emit(self, signal, params=None):
        self.bus.emit_signal(None, SNI_PATH, "org.kde.StatusNotifierItem",
                             signal, params)

    def sni_get(self, _conn, _sender, _path, _iface, prop):
        icon = "whatsapp-unread" if self.count else "whatsapp"
        values = {
            "Category": GLib.Variant("s", "Communications"),
            "Id": GLib.Variant("s", "whatsapp-tray"),
            "Title": GLib.Variant("s", "WhatsApp"),
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
            self.open_window()
        elif method == "SecondaryActivate":
            self.set_count(0)
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
            self.open_window()
        elif item_id == 2:
            self.set_count(0)

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


def watch_lines(fd, on_line):
    """Call on_line for each line read from fd; quit when it closes."""
    stream = Gio.DataInputStream.new(Gio.UnixInputStream.new(fd, False))

    def read_next(*_):
        stream.read_line_async(GLib.PRIORITY_DEFAULT, None, got_line)

    def got_line(src, result):
        line, _ = src.read_line_finish_utf8(result)
        if line is None:
            print("event source closed", file=sys.stderr)
            os._exit(1)  # the systemd unit restarts us
        on_line(line)
        read_next()

    read_next()


def main():
    tray = Tray()
    tray.export()

    # Hyprland window events.
    hypr = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    hypr.connect(os.path.join(HYPR, ".socket2.sock"))
    watch_lines(hypr.fileno(), tray.on_hypr_event)

    # Every desktop notification sent on the session bus. The body's first
    # line is "web.whatsapp.com" for WhatsApp's.
    monitor = subprocess.Popen(
        ["dbus-monitor", "--session",
         "type='method_call',interface='org.freedesktop.Notifications',"
         "member='Notify'"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    def on_notify_line(line):
        if line.lstrip().startswith('string "web.whatsapp.com'):
            tray.on_message()

    watch_lines(monitor.stdout.fileno(), on_notify_line)

    try:
        GLib.MainLoop().run()
    finally:
        monitor.terminate()


if __name__ == "__main__":
    main()
