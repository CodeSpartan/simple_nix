# nixpkgs' wayle with our fixes on top. Rebuilds wayle from source (a few
# minutes) -- nothing else changes. Each patch is explained where it's applied.
# On a wayle bump: if a patch no longer applies, check whether upstream fixed
# that bug (then drop it) or the code moved (then refresh the patch).
final: prev:

{
  wayle = prev.wayle.overrideAttrs (old: {
    # The bar's "network" module falls back to a wifi device's (possibly
    # disconnected) state whenever NetworkManager's primary connection isn't
    # plain Wifi/Wired/None -- which is always, on this machine, since iVPN's
    # WireGuard tunnel is reported as primary. Prefer an actually-connected
    # wired device in that fallback instead.
    #
    # The tray shows every icon, even ones whose app asks to be hidden (SNI
    # status "Passive", e.g. blueman while Bluetooth is off). Hide those; the
    # second half (wayle-systray-newstatus.patch, below) makes wayle notice
    # the NewStatus signal apps send when the status changes.
    patches = (old.patches or [ ]) ++ [
      ./wayle-network-prefer-wired.patch
      ./wayle-systray-hide-passive.patch
    ];

    # The rest patch libraries wayle downloads (vendored crates), so they
    # can't go in `patches`.
    postPatch = (old.postPatch or "") + ''
      # Wayle bug (in the wayle-notification crate): a notification sent with
      # expire_timeout 0 means "never expires", but wayle treats it as already
      # expired and drops it from its list right away (the popup still shows).
      # Closing that popup then finds nothing to remove, so the app never gets
      # NotificationClosed -- e.g. KClock keeps ringing after the popup's X.
      # Upstream: https://github.com/wayle-rs/wayle-services/pull/53
      substituteInPlace "$cargoDepsCopy"/*/wayle-notification-0.1.3/src/monitoring.rs \
        --replace-fail \
          'let Some(ttl) = notif_arc.expire_timeout.get() else {' \
          'let Some(ttl) = notif_arc.expire_timeout.get().filter(|t| *t != 0) else {'

      # Second wayle bug, same symptom: KClock closes its old notification and
      # resends it with replaces_id = the old id. Wayle has already forgotten
      # that id, so it hands out a new one -- and KClock, still listening for
      # the old id, ignores the NotificationClosed for the new one. Reuse a
      # replaces_id that no other app owns instead of only one this app owns.
      # Upstream: https://github.com/wayle-rs/wayle-services/pull/54
      # Drop both once wayle ships a wayle-notification with them.
      substituteInPlace "$cargoDepsCopy"/*/wayle-notification-0.1.3/src/daemon.rs \
        --replace-fail \
          '.is_some_and(|owner| owner == app_name);' \
          '.is_none_or(|owner| owner == app_name);'

      # Tray: update an icon's status on the NewStatus signal (wayle only read
      # it from PropertiesChanged, which blueman never sends).
      patch -d "$(echo "$cargoDepsCopy"/*/wayle-systray-0.1.3)" -p1 < ${./wayle-systray-newstatus.patch}

      # Tray: after a bar restart, the scan for "orphaned" tray items re-added
      # apps that had registered by well-known name (org.kde.StatusNotifierItem-
      # <pid>-1) under their unique name too -> duplicate icons (v2rayN).
      # Drop once wayle-rs/wayle-services#34 (fixes the same bug) ships here.
      patch -d "$(echo "$cargoDepsCopy"/*/wayle-systray-0.1.3)" -p1 < ${./wayle-systray-dedup.patch}
    '';
  });
}
