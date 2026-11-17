# KClock 26.08.3: a one-time alarm sometimes rang again the next day after
# being dismissed. Alarm::dismiss() only disables it when m_justSnoozed is
# false, but that bool is never initialized (src/kclockd/alarm.h), so a
# garbage "true" made a dismiss act like a snooze. Initialize it to false.
# Drop once nixpkgs' kclock has the fix (upstream MR: see CLAUDE.md TODO).
final: prev: {
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    kclock = kprev.kclock.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/kclockd/alarm.h \
          --replace-fail "bool m_justSnoozed;" "bool m_justSnoozed = false;"
      '';
    });
  });
}
