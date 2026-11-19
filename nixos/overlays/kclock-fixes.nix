# Two kclockd (KClock 26.08.3) alarm fixes, both sent upstream:
# - A one-time alarm sometimes rang again the next day after being
#   dismissed: Alarm::dismiss() only disables it when m_justSnoozed is
#   false, but that bool was never initialized (src/kclockd/alarm.h).
#   Upstream MR 281 (merged 2026-11-17).
# - A renamed alarm's notification showed its old name: the title is set
#   once when kclockd loads the alarm, never on rename. Set it again each
#   time the alarm rings (Alarm::ring()). Upstream MR: see CLAUDE.md TODO.
# Drop each once nixpkgs' kclock has it (its --replace-fail then fails).
final: prev: {
  kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
    kclock = kprev.kclock.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/kclockd/alarm.h \
          --replace-fail "bool m_justSnoozed;" "bool m_justSnoozed = false;"
        substituteInPlace src/kclockd/alarm.cpp \
          --replace-fail \
            "        m_notification->setText(QLocale::system().toString(QTime::currentTime(), QLocale::ShortFormat));" \
            "        m_notification->setTitle(m_name.isEmpty() ? i18n(\"Alarm\") : m_name);
        m_notification->setText(QLocale::system().toString(QTime::currentTime(), QLocale::ShortFormat));"
      '';
    });
  });
}
