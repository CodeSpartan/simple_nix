#!/usr/bin/env python3
"""Switch keyboard layout when Hyprland emits the custom event "kb-switch".

The Ctrl+Shift binds in user.lua could run `hyprctl switchxkblayout` with
exec_cmd, but every exec makes Hyprland fork itself first, and the switch
then lands ~50 ms after the key release -- a fast first letter still came
out in the old layout. hl.dsp.event() spawns nothing: it writes
"custom>>kb-switch" to the event socket, and this long-running helper answers
with the same command over the request socket (< 1 ms).

Autostarted from user.lua. If it isn't running, Ctrl+Shift does nothing
(Super+Space still works -- that one is XKB's own).
"""
import os
import socket
import sys
import time

EVENT = b"custom>>kb-switch"
COMMAND = b"switchxkblayout all next"

runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
if not sig:
    sys.exit("kb-switch: HYPRLAND_INSTANCE_SIGNATURE not set")
hypr = os.path.join(runtime, "hypr", sig)


def switch():
    with socket.socket(socket.AF_UNIX) as c:
        c.connect(os.path.join(hypr, ".socket.sock"))
        c.sendall(COMMAND)
        c.recv(4096)


def listen():
    with socket.socket(socket.AF_UNIX) as s:
        s.connect(os.path.join(hypr, ".socket2.sock"))
        buf = b""
        while chunk := s.recv(65536):
            buf += chunk
            *lines, buf = buf.split(b"\n")
            for line in lines:
                if line == EVENT:
                    try:
                        switch()
                    except OSError as e:
                        print(f"kb-switch: switch failed: {e}", file=sys.stderr)


# Reconnect if the socket drops; exit once this Hyprland instance is gone.
while os.path.isdir(hypr):
    try:
        listen()
    except OSError as e:
        print(f"kb-switch: event socket: {e}", file=sys.stderr)
    time.sleep(1)
