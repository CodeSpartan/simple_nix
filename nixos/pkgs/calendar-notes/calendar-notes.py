"""Day notes from calcurse, for the Wayle bar and a morning notification.

  calendar-notes wayle            JSON for the Wayle bar module (today's count,
                                  tooltip with today's and tomorrow's notes)
  calendar-notes wayle-watch      the same, printed again whenever calcurse
                                  saves or the date changes (Wayle watch mode)
  calendar-notes notify [--force] one desktop notification with today's notes,
                                  at most once a day (--force: send anyway)
  calendar-notes today            today's notes as plain text
  calendar-notes import-rainlendar FILE
                                  load a Rainlendar Default.ics into calcurse
                                  (only into an empty calendar)

calcurse keeps its data in ~/.local/share/calcurse: `apts` (one line per
item) and `notes/<hash>` (an item's longer text).
"""

import datetime as dt
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HOME = Path.home()
# Same lookup as calcurse itself (it follows XDG_DATA_HOME, not HOME).
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "calcurse"
STATE = HOME / ".local/state/calendar-notes"
TITLE_MAX = 80
SEP = "\x1f"  # between an item's text and its note hash in calcurse output


def notes_for(first, days):
    """{date: [(title, note_text)]} for `days` days starting at `first`."""
    fmt_apt = f"%S %m{SEP}%n\\n"
    fmt_event = f"%m{SEP}%n\\n"
    out = subprocess.run(
        ["calcurse", "--input-datefmt", "4", "--output-datefmt", "%F",
         "-Q", "--from", first.isoformat(), "--days", str(days),
         "--format-apt", fmt_apt, "--format-recur-apt", fmt_apt,
         "--format-event", fmt_event, "--format-recur-event", fmt_event],
        capture_output=True, text=True).stdout
    result, day = {}, None
    for line in out.splitlines():
        if re.fullmatch(r"\d{4}-\d\d-\d\d:", line):
            day = dt.date.fromisoformat(line[:-1])
        elif day and SEP in line:
            title, note = line.split(SEP, 1)
            text = ""
            if note and note != "(null)":
                try:
                    text = (DATA / "notes" / note).read_text().strip()
                except OSError:
                    pass
            result.setdefault(day, []).append((title.strip(), text))
    return result


# --- wayle --------------------------------------------------------------------

def wayle_json():
    import json
    today = dt.date.today()
    tomorrow = today + dt.timedelta(days=1)
    days = notes_for(today, 2)
    lines = []
    for label, d in (("Today", today), ("Tomorrow", tomorrow)):
        if lines:
            lines.append("")
        lines.append(f"{label}, {d:%a %d %b}")
        lines += [f"  • {t}" for t, _ in days.get(d, [])] or ["  nothing"]
    lines += ["", "Click: open calendar"]
    n = len(days.get(today, []))
    return json.dumps({"text": str(n) if n else "", "tooltip": "\n".join(lines),
                       "alt": "notes" if n else "none"}, ensure_ascii=False)


def cmd_wayle():
    print(wayle_json())


def cmd_wayle_watch():
    """Reprint when calcurse saves `apts` or the day changes (checked every 2 s,
    a stat call, so the bar shows a new note as soon as calcurse writes it)."""
    last = None
    while True:
        try:
            mtime = (DATA / "apts").stat().st_mtime_ns
        except OSError:
            mtime = None
        key = (mtime, dt.date.today())
        if key != last:
            last = key
            print(wayle_json(), flush=True)
        time.sleep(2)


# --- notify / today -----------------------------------------------------------

def today_text(todays):
    parts = []
    for title, note in todays:
        parts.append(f"• {title}")
        # Show the full note when it says more than the title.
        if note and note != title:
            body = note if len(note) <= 400 else note[:400] + "…"
            parts.append("   " + body.replace("\n", "\n   "))
    return "\n".join(parts)


def notification_daemon_up():
    r = subprocess.run(
        ["busctl", "--user", "status", "org.freedesktop.Notifications"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def cmd_notify(force):
    today = dt.date.today()
    stamp_file = STATE / "last-notified"
    if not force and stamp_file.exists() and stamp_file.read_text().strip() == today.isoformat():
        return
    todays = notes_for(today, 1).get(today, [])
    if todays:
        # At login the bar (which shows notifications) may still be starting.
        for _ in range(60):
            if notification_daemon_up():
                break
            time.sleep(2)
        else:
            sys.exit("no notification daemon; will retry next time")
        time.sleep(3)
        n = len(todays)
        subprocess.run([
            "notify-send", "--app-name=Calendar", "--icon=x-office-calendar",
            "--expire-time=0",  # stay until dismissed
            f"{n} note{'s' if n > 1 else ''} for today, {today:%a %d %b}",
            today_text(todays)], check=True)
    STATE.mkdir(parents=True, exist_ok=True)
    stamp_file.write_text(today.isoformat() + "\n")


def cmd_today():
    today = dt.date.today()
    todays = notes_for(today, 1).get(today, [])
    print(today_text(todays) if todays else "No notes today.")


# --- import-rainlendar --------------------------------------------------------

def rainlendar_title(ev):
    """Rainlendar keeps the note in DESCRIPTION and leaves SUMMARY empty."""
    summary = str(ev.get("SUMMARY", "")).strip()
    if summary:
        return summary, False
    desc = str(ev.get("DESCRIPTION", "")).strip()
    for line in desc.splitlines():
        line = re.sub(r"^[\s\-•*=_]+", "", line).strip()
        if line.strip("=_ "):
            title = line if len(line) <= TITLE_MAX else line[:TITLE_MAX - 1] + "…"
            # A one-line note needs no separate note text.
            return title, (title == desc)
    # Colour-only day marker: name it after its category ("[Green]" -> "Green").
    cats = ev.get("CATEGORIES")
    cat = cats.to_ical().decode() if cats else ""
    return (cat.strip("[]") or "Marked day"), False


def cmd_import(src):
    import icalendar
    apts = DATA / "apts"
    if apts.exists() and apts.stat().st_size > 0:
        sys.exit(f"{apts} is not empty; calcurse doesn't skip duplicates, so not importing")
    cal = icalendar.Calendar.from_ical(Path(src).read_bytes())
    for ev in cal.walk("VEVENT"):
        title, drop_desc = rainlendar_title(ev)
        if "SUMMARY" in ev:
            del ev["SUMMARY"]
        ev.add("SUMMARY", title)
        if drop_desc and "DESCRIPTION" in ev:
            del ev["DESCRIPTION"]
    DATA.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".ics", delete=False) as f:
        f.write(cal.to_ical())
    try:
        subprocess.run(["calcurse", "-i", f.name], check=True)
    finally:
        os.unlink(f.name)


def main():
    args = sys.argv[1:]
    if args[:1] == ["wayle"]:
        cmd_wayle()
    elif args[:1] == ["wayle-watch"]:
        cmd_wayle_watch()
    elif args[:1] == ["notify"]:
        cmd_notify(force="--force" in args)
    elif args[:1] == ["today"]:
        cmd_today()
    elif args[:1] == ["import-rainlendar"] and len(args) == 2:
        cmd_import(args[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
