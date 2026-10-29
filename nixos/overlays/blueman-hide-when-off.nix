# Blueman's tray icon normally stays whenever a Bluetooth adapter exists, even
# with Bluetooth off. Show it only while Bluetooth is on. To turn Bluetooth on,
# open "Bluetooth Manager" (blueman-manager) and use its on/off switch.
# Hiding needs wayle-systray-hide-passive.patch: wayle's tray otherwise
# ignores an app's request to hide its icon.
final: prev: {
  blueman = prev.blueman.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./blueman-hide-when-off.patch ];
  });
}
