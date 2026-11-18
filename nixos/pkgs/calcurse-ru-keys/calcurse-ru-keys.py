# Give every calcurse hotkey a twin on the Russian (ЙЦУКЕН) layout: the
# key in the same place, so `a` (add) also works as `ф`, `>` as `Ю`.
#
# Runs before calcurse starts (calendar-open). calcurse rewrites its keys
# file from its own key menu, so this re-derives the twins every time:
# Cyrillic keys are dropped and added again from the current Latin ones,
# which keeps them right after a rebinding. A key bound to two actions makes
# calcurse refuse to start, so a twin already in use is skipped.
import os
import sys
import tempfile

LOWER = dict(zip("qwertyuiop[]asdfghjkl;'zxcvbnm,./`",
                 "йцукенгшщзхъфывапролджэячсмитьбю.ё"))
UPPER = dict(zip('QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?~@#$&|',
                 'ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё"№;?/'))
RU = LOWER | UPPER


def ours(key):
    """A key this script adds: Cyrillic, plus №."""
    return len(key) == 1 and ("Ѐ" <= key <= "ӿ" or key == "№")


def main(path):
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except FileNotFoundError:
        return  # first start: calcurse writes its defaults; twins next time

    rows = []  # (label, keys) or the raw line for comments/blank lines
    for line in lines:
        parts = line.split()
        if not parts or line.lstrip().startswith("#"):
            rows.append(line)
        else:
            # Drop earlier twins: Cyrillic ones, and punctuation that is the
            # twin of another key of the same action (`"` next to `@`).
            twins = {RU[k] for k in parts[1:] if k in RU}
            rows.append((parts[0], [k for k in parts[1:]
                                    if not ours(k) and k not in twins]))

    used = {k for r in rows if isinstance(r, tuple) for k in r[1]}
    for r in rows:
        if not isinstance(r, tuple):
            continue
        for key in list(r[1]):
            twin = RU.get(key)
            if twin and twin not in used:
                r[1].append(twin)
                used.add(twin)

    out = "\n".join(r if isinstance(r, str) else f"{r[0]}  {' '.join(r[1])}"
                    for r in rows) + "\n"
    if out == "\n".join(lines) + "\n":
        return
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".keys.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


if __name__ == "__main__":
    main(sys.argv[1])
