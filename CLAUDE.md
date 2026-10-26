# CLAUDE.md

Guidance for Claude Code when working in this repo / on this machine.

## Who's using this

The user is a **first-time Linux user** — this is their first NixOS install,
their only prior experience is Ubuntu-on-a-server-through-Claude. Don't
assume familiarity with Linux/Nix concepts, jargon, or muscle memory (sudo,
systemd, symlinks, etc.). Explain what a command does before/while running
it, not just that it worked. Prefer showing the exact commands they'd need
to run themselves over assuming they know the equivalent.

They program but don't do ML (yet) — the CUDA/cuDNN/Nsight/Jupyter stack
inherited from Vitalii stays anyway, they may learn ML later. Don't trim it.

## This machine

Desktop, set up fresh 2026-10-26. Replaces the old Intel/no-GPU laptop this
fork first ran on — that laptop is **retired**. Any "weak hardware" framing
from that era no longer applies.

- AMD Ryzen 9 3900X (12c/24t), 32GB RAM, NVIDIA RTX 4080 SUPER, btrfs root.
- **MSI** motherboard (AMI firmware) — *not* the ASRock board the README's
  BIOS steps describe; menu names differ (see Secure Boot below).
- Monitor: 4K, scale **2** — set in `config/hypr/user.lua`.
- Network: two onboard ethernet ports. `enp35s0` (Realtek, `r8169`) is the
  one in use. `eno1` (Killer/Atheros, `alx`) is unused and its driver is
  **blacklisted** in `nixos/hardware.nix` (see Wayle below for why).
  Intel wifi (`wlp36s0`, `iwlwifi`) is present but its radio is off; it is
  deliberately *not* blacklisted — the user wants wifi available.
- This is a fork of a friend's (Vitalii's) config, originally tuned for *his*
  machine (~32GB, 4K, NVIDIA) — this box is close to that spec, so
  upstream's un-tuned defaults (`nvidia = true`, `cores = 0`,
  `max-jobs = "auto"`, `linuxPackages_latest`) are correct here.

## TODO

- Logitech mouse software: figure out the exact model, then wire up either
  **Solaar** (`pkgs.solaar` — Unifying/Bolt receiver, battery/pairing/DPI)
  or **Piper** + `services.ratbagd.enable` (`pkgs.piper` — G-series DPI/
  button remap/RGB), analogous to how Razer gets OpenRazer+Polychromatic
  on Vitalii's upstream. Not installed yet.
- `config/hypr/user.conf` is dead (see Hyprland below) — could be deleted.

## Repo vs. system config — where to make a change

- **`nixos/*.nix`** (packages, services, hardware, users) → edit in this
  repo, then `./install.sh` (rebuild + relink dotfiles + flatpak update).
  Never hand-edit `/etc/nixos` — it's not used; everything points at this
  flake. (`/etc/nixos/configuration.nix` still holds a stale hand-patch from
  install day; ignore it.)
- **Plain dotfiles** (`config/hypr/user.lua`, kitty, rofi, wayle) → symlinked
  live by `link.sh`. Edit in the repo; takes effect after an app reload
  (`hyprctl reload`, `wayle panel restart`) — **no `./install.sh` needed.**
- **home-manager-managed dotfiles** (git config, ssh config, mc, kde theming
  — `nixos/home/*.nix`) → **read-only symlinks into the Nix store**. Can't
  hand-edit `~/.gitconfig`/`~/.ssh/config`; change the source, then
  `./install.sh`.
- Kernel-module blacklists (`boot.blacklistedKernelModules`) only take effect
  at boot — a running module stays loaded after `./install.sh` until reboot
  (or `sudo modprobe -r <module>`).
- After a rebuild that changes a running app (e.g. wayle), the old process
  keeps the old binary — restart the app, no reboot needed.

## install.sh behaviour

- Uses Vitalii's fix for a real failure mode: `nixos-rebuild switch` exits
  **4** when the new generation activated but some unrelated unit failed
  (e.g. `fwupd-refresh`). Exit 4 → warn and continue; any other non-zero →
  abort. Before that fix, `set -e` killed the script before `link.sh`, so
  no dotfiles got linked and Hyprland booted into emergency mode with a
  misleading "cannot open user.lua".
- If dotfiles ever look missing after a rebuild, just run `./link.sh`.
- Installs/updates **Discord** via *system* Flatpak (Blender from upstream's
  version deliberately dropped). Discord also exists as a *user* Flatpak
  from install day — both coexist on purpose; leave them.
- `nixos/hardware-configuration.nix` is gitignored. `install.sh` stages it
  temporarily so the flake can see it; if a run dies early it can be left
  staged — check `git status` before committing so it isn't committed.
- Never run the whole script with `sudo ./install.sh` — it calls sudo itself
  where needed; running it as root breaks git's ownership checks and leaves
  root-owned files in `.git/objects` (fix: `sudo chown -R vervain:users
  ~/code/simple_nix` — primary group is `users`, not `vervain`).

## Hyprland

Upstream migrated to a Lua config: `~/.config/hypr/hyprland.lua`
(home-manager) just `dofile`s `config/hypr/user.lua`, which is the real
config. `config/hypr/user.conf` is **not linked or loaded** anymore.
Monitor scale (2), cursor size (32), `GDK_SCALE`/`GDK_DPI_SCALE` and the
NVIDIA xwayland/cursor workarounds all live in `user.lua`.

## Wayle (status bar)

- **`~/.config/wayle/local.toml` must exist.** `config.toml` does
  `imports = ["local.toml"]`; despite its own comment, a missing import makes
  wayle drop the **whole** config and fall back to its stock bar. It holds
  the weather location (`Saint Petersburg, Russia`) and is outside git on
  purpose. Template: `config/wayle/local.toml.example`.
- Network module said "Disconnected" while online. Two bugs:
  1. wayle-shell preferred a merely-present wifi device over wired when NM's
     primary connection is VPN/WireGuard (always, here) — **patched** in
     `nixos/overlays/wayle-network-prefer-wired.patch`.
  2. The external `wayle-network` crate picks the *first* ethernet device NM
     enumerates, not the active one; `eno1` was listed first. Patching that
     crate via Cargo `[patch]` doesn't work with nixpkgs' `cargoHash`
     vendoring (would need `cargoLock` + `outputHashes`) — so instead `alx`
     is blacklisted to remove `eno1`. If that port is ever needed, remove the
     blacklist and the bar will say "Disconnected" again (cosmetic only).
- Known, harmless: a once-a-second `missing field overFullscreen` log spam
  (wayle vs newer Hyprland IPC); weather shows `--` because open-meteo times
  out through iVPN; two identical iVPN tray icons (bug in iVPN's Electron
  app — both come from the same PID; leave it).
- wayle is built from a PR branch (`nixos/overlays/wayle-pr255*.nix`). Its
  `postPatch` still disables LTO for the old 7.5GB laptop — harmless here.

## NVIDIA / kernel / sleep

- The raw installer used **nouveau**, which froze/corrupted the screen on the
  4080 SUPER. The flake's `nvidia-open` driver fixes it.
- Kernel/driver pairing comes from `flake.lock`'s pinned nixpkgs; a plain
  channel once paired kernel 7.3 with an `nvidia-open` that didn't compile.
  If a nixpkgs bump breaks the nvidia build, suspect that pairing first.
- **Suspend is dangerous**: S3 resume with the open driver gives `Xid 13`
  graphics exceptions and a dead display (hard reset needed). The repo masks
  all sleep targets in `hardware.nix`; Plasma's own auto-sleep is also off.
- After a forced power-off mid-build the Nix store can hold 0-byte corrupt
  paths (builds fail with "gzip: unexpected end of file"). Fix:
  `sudo nix-store --verify --check-contents --repair`.

## Secure Boot

Done and verified (`bootctl status` → `Secure Boot: enabled (user)`,
Lanzaboote stub active). MSI-specific lessons, in case keys are ever reset:
- In BIOS (Advanced → Windows OS Configuration → Secure Boot → Key
  Management), **"Provision Factory Default keys" must stay Disabled** —
  when enabled, the firmware silently reinstalls the factory keys on every
  boot, undoing any delete. Deleting just the PK is enough to enter Setup
  Mode once that's off.
- Exit with **Save & Exit → Save Changes and Reset**; a "reset without
  saving?" prompt discards the change.
- `sbctl enroll-keys` may fail with "File is immutable" for efivars — clear
  it with `sudo nix-shell -p e2fsprogs --run "chattr -i <files>"`.
- `sbctl` flags firmware quirk FQ0001 on this board; expected.
- Windows boots fine (Microsoft certs enrolled via `--microsoft`); use F11
  at POST to pick it. BitLocker will ask for its recovery key once after the
  key change.
- Old Ubuntu/Fedora entries are still in the firmware boot list — leftovers.

## Git remotes / GitHub

- `origin` → `git@github.com:CodeSpartan/simple_nix.git` (user's fork, SSH —
  HTTPS has no stored credentials, pushes over it fail).
- `upstream` → `https://github.com/Lallapallooza/simple_nix.git` (Vitalii's;
  read-only in practice — pull fixes from here, don't push).
- `gh` is authenticated as `CodeSpartan` with `git_protocol ssh`.
- Pulling upstream: `git fetch upstream`, `git log HEAD..upstream/main`, then
  **cherry-pick** what's wanted — never a blind merge. `host.nix`,
  `hardware.nix`, `security.nix`, `secrets/` and `hypr/user.lua` are
  machine-specific (username, scale, locale, alx blacklist, secrets) and
  diverge on purpose. Skip upstream's NordVPN, Razer/openrazer and personal
  secrets (e.g. `vastai.age`). Vitalii is reachable by the user on Discord.
- PRs **upstream**: build in a clean `git worktree` off `upstream/main`, never
  from this working tree.
- Cloning over HTTPS from Claude's shell can pop a GUI password prompt
  (ksshaskpass) on the user's desktop — prefix with
  `GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true` (NixOS has no `/bin/true`).

## Secrets (agenix)

- Personal age key: `~/.config/age/keys.txt` — **generated fresh on this
  machine 2026-10-27**; the old laptop's key was lost, so its secrets were
  undecryptable and dropped. The user should keep a copy of this private key
  in a password manager — without it, the secrets below can't be decrypted
  on a reinstall.
- Secrets: `id_ed25519_github`, `id_ed25519_gitlab` — SSH keys generated on
  this machine, public halves registered on GitHub (`CodeSpartan`) and GitLab
  (`@Glabrezu`); decrypted to `/run/agenix/` and used via `~/.ssh/config`.
  agenix decrypts at activation, so new secrets work right after
  `./install.sh`, no reboot.
- Add more with `./scripts/add-secret.sh <name>` (reads the value from
  stdin). Never read private key material into Claude's context — generate
  to a file and pipe it in (`cat key | ./scripts/add-secret.sh name`), then
  shred the plaintext.
- Never try to decrypt or use Vitalii's secrets (`vastai.age` etc.) — wrong
  key, and not this user's credentials.

## iVPN — do not touch without explicit permission

The user manages their iVPN connection (connect/disconnect/server/protocol)
themselves. **Never run `ivpn connect`/`disconnect`/etc. on your own
initiative**, even to test something — disconnecting once briefly left the
firewall/kill-switch off. Ask first. The daemon (`ivpn-service`) now starts
at boot (the repo's no-autostart override was removed at the user's request).

Side effect worth knowing: some hosts are unreachable through the VPN exit
(crates.io's REST API → 403, open-meteo → TLS timeout). Cargo's registry
works fine. Claude's WebFetch/WebSearch don't go through it.

## AI tools

`claude` and `codex` live in `~/.local/bin`, installed by
`scripts/install-ai-tools.sh` — **not** part of the Nix rebuild. `claude`
self-updates; no need to rerun the script after reboots/updates.

## Debugging the live desktop session

This session's Bash tool can reach the real Hyprland session:
```bash
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1   # confirm via: ls /run/user/1000 | grep wayland
grim /path/in/scratchpad/screenshot.png   # then Read it; crop with imagemagick
```
- Wayle logs: `~/.local/state/wayle/wayle-shell.<date>.log` (the date can lag
  a day behind local time).
- Restart the bar with `wayle panel restart` — not by killing the process and
  launching another instance.
- Boot history for crash forensics: `journalctl --list-boots`, then
  `journalctl -b -1`.
- `sudo`, `gh auth login`, `add-secret.sh` pastes, anything needing an
  interactive password/browser prompt **cannot** run from this tool — hand
  back exact commands (the user can run them with the `!` prefix).

## Flatpak apps

`services.flatpak.enable` only enables the service; apps live outside Nix.
Discord is Flatpak on purpose (nixpkgs' `patchelf`'d build caused
screen-share bugs). `install.sh` now installs/updates Discord system-wide
and runs `flatpak update`; anything else is manual
(`flatpak install --user flathub <app-id>`, Flathub exists as both a system
and a user remote).

## `~/Desktop/message to vitalii.txt`

Brief running log of upstream-worthy findings for Vitalii (install.sh,
wayle `local.toml`, `overFullscreen`, the two network-module bugs). Keep it
current; don't pad it with machine-specific or personal-preference stuff.

## Claude Code statusline

Not configured on this machine yet (the old laptop had one: reset
countdown, quota % used, fresh session tokens). Use the `statusline-setup`
agent if the user wants it back.
