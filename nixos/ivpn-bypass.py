"""Keep listed apps outside the iVPN tunnel, however they are launched.

iVPN's split tunnel excludes every process in the cgroup
/sys/fs/cgroup/net_cls/ivpn-exclude (that is all `ivpn exclude <app>` does:
start the app and write its PID there). This daemon does the same for any
process whose name is in the apps file, the moment it starts. Children
inherit the cgroup, so a whole app (browser tabs, helpers) goes with it.

The apps file is re-read within a second of being saved. Removing a name
moves that app's processes back into the tunnel (only ones this daemon
moved; PIDs added by hand with `ivpn exclude` are left alone).

Requires split tunnel to be on (`ivpn splittun -on`) and NOT in inverse
mode -- in inverse mode the same cgroup means "only these use the VPN".

Usage: ivpn-bypass.py <apps-file>   (runs as root)
"""

import os
import select
import socket
import struct
import sys
import time

BUCKET = "/sys/fs/cgroup/net_cls/ivpn-exclude"
ROOT = "/sys/fs/cgroup/net_cls"
RESCAN_EVERY = 10  # seconds; catches iVPN re-creating/emptying the bucket

# Kernel process-event connector (linux/cn_proc.h)
NETLINK_CONNECTOR = 11
CN_IDX_PROC = 1
CN_VAL_PROC = 1
PROC_CN_MCAST_LISTEN = 1
EV_FORK, EV_EXEC, EV_COMM, EV_EXIT = 0x1, 0x2, 0x200, 0x80000000
EV_OFFSET = 16 + 20  # nlmsghdr + cn_msg
DATA_OFFSET = EV_OFFSET + 16  # what, cpu, timestamp


def log(msg):
    print(msg, flush=True)


class Bypass:
    def __init__(self, apps_file):
        self.apps_file = apps_file
        self.apps = set()
        self.file_sig = None
        self.ours = {}  # PID -> list entry it was bypassed for

    # ---- config ----------------------------------------------------------

    def reload_if_changed(self):
        try:
            st = os.stat(self.apps_file)
            sig = (st.st_ino, st.st_mtime_ns, st.st_size)
        except OSError:
            sig = None
        if sig == self.file_sig:
            return False
        self.file_sig = sig
        apps = set()
        if sig is not None:
            with open(self.apps_file) as f:
                for line in f:
                    name = line.split("#", 1)[0].strip().lower()
                    if name:
                        apps.add(name)
        if apps != self.apps:
            log(f"apps list: {sorted(apps) or '(empty)'}")
        self.apps = apps
        return True

    # ---- process inspection ----------------------------------------------

    @staticmethod
    def names(pid):
        """Every name a process could reasonably be known by."""
        out = set()
        try:
            with open(f"/proc/{pid}/comm") as f:
                out.add(f.read().strip())
        except OSError:
            return out
        try:
            out.add(os.path.basename(os.readlink(f"/proc/{pid}/exe")))
        except OSError:
            pass
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                argv0 = f.read().split(b"\0", 1)[0].decode(errors="replace").strip()
            if argv0:
                out.add(os.path.basename(argv0.split()[0]))
        except OSError:
            pass
        cleaned = set()
        for n in out:
            n = n.lower()
            if not n:
                continue
            cleaned.add(n)
            # Nix wraps binaries as .foo-wrapped (comm truncates to 15 chars)
            stripped = n.lstrip(".")
            for suffix in ("-wrapped", "-wrappe", "-wrapp"):
                if stripped.endswith(suffix):
                    stripped = stripped[: -len(suffix)]
                    break
            cleaned.add(stripped)
        return cleaned

    def match(self, pid):
        """The list entry this process matches, or None."""
        if not self.apps:
            return None
        hit = self.apps & self.names(pid)
        return min(hit) if hit else None

    @staticmethod
    def ppid(pid):
        try:
            with open(f"/proc/{pid}/stat") as f:
                return int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return 0

    @staticmethod
    def in_bucket(pid):
        try:
            with open(f"/proc/{pid}/cgroup") as f:
                return any(
                    ":net_cls" in line and line.rstrip().endswith("/ivpn-exclude")
                    for line in f
                )
        except OSError:
            return False

    # ---- moving ----------------------------------------------------------

    def move_in(self, pid, app, quiet=False):
        if not os.path.isdir(BUCKET):
            return
        if not self.in_bucket(pid):
            try:
                with open(f"{BUCKET}/cgroup.procs", "w") as f:
                    f.write(str(pid))
            except OSError:
                return  # process already gone
            if not quiet:
                log(f"bypass {pid} ({app})")
        self.ours[pid] = app

    def move_out(self, pid):
        self.ours.pop(pid, None)
        try:
            with open(f"{ROOT}/cgroup.procs", "w") as f:
                f.write(str(pid))
            log(f"back into VPN: {pid}")
        except OSError:
            pass

    def rescan(self):
        """Move every matching process (and its descendants) in. Move out
        only processes bypassed for an entry that was removed from the list
        -- a helper whose listed parent exited stays bypassed."""
        if not os.path.isdir(BUCKET):
            self.ours.clear()
            return
        pids = [int(p) for p in os.listdir("/proc") if p.isdigit()]
        alive = set(pids)
        self.ours = {p: a for p, a in self.ours.items() if p in alive}
        parent = {p: self.ppid(p) for p in pids}
        memo = {}

        def app_for(p):
            chain = []
            while p > 1 and p not in memo:
                hit = self.match(p) or (
                    self.ours[p] if self.ours.get(p) in self.apps else None
                )
                if hit:
                    memo[p] = hit
                    break
                chain.append(p)
                p = parent.get(p, 0)
            result = memo.get(p)
            for c in chain:
                memo[c] = result
            return result

        for p in pids:
            app = app_for(p)
            if app:
                self.move_in(p, app)
            elif p in self.ours:
                self.move_out(p)

    # ---- event loop ------------------------------------------------------

    def connect(self):
        sock = socket.socket(socket.AF_NETLINK, socket.SOCK_DGRAM, NETLINK_CONNECTOR)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
        sock.bind((os.getpid(), CN_IDX_PROC))
        payload = struct.pack("=I", PROC_CN_MCAST_LISTEN)
        cn = struct.pack("=IIIIHH", CN_IDX_PROC, CN_VAL_PROC, 0, 0, len(payload), 0)
        nl = struct.pack("=IHHII", 16 + len(cn) + len(payload), 3, 0, 0, os.getpid())
        sock.send(nl + cn + payload)
        return sock

    def handle(self, data):
        if len(data) < DATA_OFFSET + 8:
            return
        (what,) = struct.unpack_from("=I", data, EV_OFFSET)
        if what in (EV_EXEC, EV_COMM):
            pid, tgid = struct.unpack_from("=II", data, DATA_OFFSET)
            if pid == tgid and tgid not in self.ours:
                app = self.match(tgid)
                if app:
                    self.move_in(tgid, app)
        elif what == EV_FORK:
            _, ptgid, cpid, ctgid = struct.unpack_from("=IIII", data, DATA_OFFSET)
            # A child forked in the instant before its parent was moved
            if cpid == ctgid and ptgid in self.ours and ctgid not in self.ours:
                self.move_in(ctgid, self.ours[ptgid], quiet=True)
        elif what == EV_EXIT:
            pid, tgid = struct.unpack_from("=II", data, DATA_OFFSET)
            if pid == tgid:
                self.ours.pop(tgid, None)

    def run(self):
        sock = self.connect()
        self.reload_if_changed()
        if not os.path.isdir(BUCKET):
            log(f"waiting for {BUCKET} -- run `ivpn splittun -on`")
        self.rescan()
        last_scan = last_check = time.monotonic()
        while True:
            ready, _, _ = select.select([sock], [], [], 1.0)
            if ready:
                try:
                    self.handle(sock.recv(4096))
                except OSError:
                    # ENOBUFS: the kernel dropped events under load
                    self.rescan()
                    last_scan = time.monotonic()
            now = time.monotonic()
            if now - last_check < 1.0:
                continue
            last_check = now
            if self.reload_if_changed() or now - last_scan > RESCAN_EVERY:
                self.rescan()
                last_scan = now


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    Bypass(sys.argv[1]).run()
