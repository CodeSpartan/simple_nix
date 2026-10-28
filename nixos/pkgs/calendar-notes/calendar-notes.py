"""Day notes from the local GNOME Calendar (Evolution Data Server) files.

  calendar-notes wayle            JSON for the Wayle bar module (today's count,
                                  tooltip with today + the next 7 days)
  calendar-notes notify [--force] one desktop notification with today's notes,
                                  at most once a day (--force: send anyway)
  calendar-notes today            today's notes as plain text
  calendar-notes import-rainlendar FILE
                                  copy a Rainlendar Default.ics into the
                                  "Personal" calendar (safe to re-run)

Reads every local calendar: ~/.local/share/evolution/calendar/*/calendar.ics
("system" is the built-in "Personal" one). Repeating events are expanded.
"""

import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

import icalendar
import recurring_ical_events

HOME = Path.home()
CAL_DIR = HOME / ".local/share/evolution/calendar"
PERSONAL = CAL_DIR / "system/calendar.ics"
STATE = HOME / ".local/state/calendar-notes"
CACHE = HOME / ".cache/calendar-notes"
UPCOMING_DAYS = 7
TITLE_MAX = 80


def calendar_files():
    return sorted(CAL_DIR.glob("*/calendar.ics"))


def load_calendars():
    cals = []
    for f in calendar_files():
        try:
            cals.append(icalendar.Calendar.from_ical(f.read_bytes()))
        except (OSError, ValueError) as e:
            print(f"skipping {f}: {e}", file=sys.stderr)
    return cals


def as_date(value):
    if isinstance(value, dt.datetime):
        if value.tzinfo is not None:
            value = value.astimezone()  # local time
        return value.date()
    return value


def notes_between(cals, first, last):
    """{date: [(sort_key, text)]} for first..last inclusive."""
    days = {}
    for cal in cals:
        for ev in recurring_ical_events.of(cal).between(first, last + dt.timedelta(days=1)):
            start = ev["DTSTART"].dt
            title = str(ev.get("SUMMARY", "")).strip() or "(no title)"
            if isinstance(start, dt.datetime):
                local = start.astimezone() if start.tzinfo else start
                key, text = local.strftime("%H:%M"), f"{local:%H:%M}  {title}"
            else:
                key, text = "", title
            # A multi-day event shows on each of its days.
            end = ev.get("DTEND")
            end = as_date(end.dt) if end else as_date(start) + dt.timedelta(days=1)
            day = max(as_date(start), first)
            while day <= last and (day < end or day == as_date(start)):
                days.setdefault(day, []).append((key, text, str(ev.get("DESCRIPTION", "")).strip()))
                day += dt.timedelta(days=1)
    for v in days.values():
        v.sort()
    return days


# --- wayle --------------------------------------------------------------------

def cmd_wayle():
    today = dt.date.today()
    # Wayle polls often; only re-read the calendars when a file or the date changed.
    stamp = today.isoformat() + "|" + "|".join(
        f"{f}:{f.stat().st_mtime_ns}" for f in calendar_files())
    cache_file = CACHE / "wayle.json"
    try:
        cached = json.loads(cache_file.read_text())
        if cached.get("stamp") == stamp:
            print(json.dumps(cached["out"], ensure_ascii=False))
            return
    except (OSError, ValueError, KeyError):
        pass

    days = notes_between(load_calendars(), today, today + dt.timedelta(days=UPCOMING_DAYS))
    todays = days.get(today, [])
    lines = [f"Today, {today:%a %d %b}"]
    lines += [f"  • {t}" for _, t, _ in todays] or ["  nothing"]
    upcoming = [d for d in sorted(days) if d != today]
    if upcoming:
        for d in upcoming:
            lines.append("")
            lines.append("Tomorrow" if d == today + dt.timedelta(days=1) else f"{d:%a %d %b}")
            lines += [f"  • {t}" for _, t, _ in days[d]]
    lines += ["", "Click: open calendar"]
    out = {
        "text": str(len(todays)) if todays else "",
        "tooltip": "\n".join(lines),
        "alt": "notes" if todays else "none",
    }
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps({"stamp": stamp, "out": out}, ensure_ascii=False))
    print(json.dumps(out, ensure_ascii=False))


# --- notify / today -----------------------------------------------------------

def today_text(todays):
    parts = []
    for _, title, desc in todays:
        parts.append(f"• {title}")
        # Show the full note when it says more than the title.
        if desc and desc != title:
            body = desc if len(desc) <= 400 else desc[:400] + "…"
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
    todays = notes_between(load_calendars(), today, today).get(today, [])
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
    todays = notes_between(load_calendars(), today, today).get(today, [])
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
            # A one-line note needs no separate description.
            return title, (title == desc)
    # Colour-only day marker: name it after its category ("[Green]" -> "Green").
    cats = ev.get("CATEGORIES")
    cat = cats.to_ical().decode() if cats else ""
    return (cat.strip("[]") or "Marked day"), False


def cmd_import(src):
    source = icalendar.Calendar.from_ical(Path(src).read_bytes())

    # Evolution Data Server keeps the calendar in memory and would overwrite
    # our change; stop it, edit the file, and let it start again on demand.
    subprocess.run(["systemctl", "--user", "stop", "evolution-calendar-factory.service"],
                   stderr=subprocess.DEVNULL)

    if PERSONAL.exists():
        target = icalendar.Calendar.from_ical(PERSONAL.read_bytes())
    else:
        target = icalendar.Calendar()
        target.add("PRODID", "-//simple_nix//calendar-notes//EN")
        target.add("VERSION", "2.0")
    have = {str(c.get("UID")) for c in target.walk("VEVENT")}

    added = 0
    for ev in source.walk("VEVENT"):
        uid = str(ev.get("UID"))
        if uid in have:
            continue
        title, drop_desc = rainlendar_title(ev)
        if "SUMMARY" in ev:
            del ev["SUMMARY"]
        ev.add("SUMMARY", title)
        if drop_desc and "DESCRIPTION" in ev:
            del ev["DESCRIPTION"]
        target.add_component(ev)
        added += 1

    PERSONAL.parent.mkdir(parents=True, exist_ok=True)
    if PERSONAL.exists():
        backup = PERSONAL.with_suffix(f".ics.bak-{int(time.time())}")
        backup.write_bytes(PERSONAL.read_bytes())
        print(f"backup: {backup}")
    tmp = PERSONAL.with_suffix(".ics.tmp")
    tmp.write_bytes(target.to_ical())
    os.replace(tmp, PERSONAL)
    print(f"imported {added} events into {PERSONAL} ({len(have)} were already there)")


def main():
    args = sys.argv[1:]
    if args[:1] == ["wayle"]:
        cmd_wayle()
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
