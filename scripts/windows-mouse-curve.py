#!/usr/bin/env python3
# Usage: python3 scripts/windows-mouse-curve.py [windows MouseSensitivity, default 16]
# Prints a Hyprland accel_profile string; paste it into config/hypr/user.lua.
# Windows 10/11 "Enhance pointer precision" -> libinput custom curve.
# Model (reverse-engineered, MarkC / Burgansky): per mouse update,
#   X = counts_per_update / 3.5 ; pixels = Y(X) * screenDPI/120 * slider/10
# screenDPI = 96*scale -> in *logical* pixels the scale cancels: 96/120 = 0.8.
# At 1000 Hz one update = 1 ms, and with no MOUSE_DPI in hwdb libinput's
# input unit is raw counts/ms -> x_libinput = 3.5 * X.
import sys
slider = float(sys.argv[1]) if len(sys.argv) > 1 else 16
WX = [0, 0.43, 1.25, 3.86, 40]
WY = [0, 1.07, 4.14, 18.98, 443.75]
px = [x * 3.5 for x in WX]
py = [y * 0.8 * slider / 10 for y in WY]
def f(x):
    for i in range(len(px) - 1):
        if x <= px[i+1] or i == len(px) - 2:
            return py[i] + (py[i+1]-py[i]) * (x-px[i]) / (px[i+1]-px[i])
step, n = 0.25, 61            # 0..15 counts/ms; past that libinput extrapolates the last segment
pts = [f(i*step) for i in range(n)]
print(f'custom {step} ' + ' '.join(f'{p:.3f}' for p in pts))
for c in (1, 2, 4.375, 8, 13.5, 30, 60):
    print(f'# {c:6} counts/ms = {c/1.75:5.1f} in/s hand speed -> gain {f(c)/c:.2f}x', file=sys.stderr)
