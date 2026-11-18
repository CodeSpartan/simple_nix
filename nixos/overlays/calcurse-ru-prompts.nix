# calcurse's yes/no-style prompts ("Press (s) to confirm", "[yn]") take
# letters hardcoded in its code, not from the keys file, so the Russian twins
# from calcurse-ru-keys (calendar.nix) don't reach them. The patch makes a
# prompt that gets a Cyrillic letter try the Latin key in the same place.
final: prev: {
  calcurse = prev.calcurse.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./calcurse-ru-prompts.patch ];
  });
}
