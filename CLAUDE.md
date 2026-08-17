# CLAUDE.md

Guidance for Claude Code when working in this repo / on this machine.

## Who's using this

The user is a **first-time Linux user** — this is their first NixOS install,
their only prior experience is Ubuntu-on-a-server-through-Claude. Don't
assume familiarity with Linux/Nix concepts, jargon, or muscle memory (sudo,
systemd, symlinks, etc.). Explain what a command does before/while running
it, not just that it worked. Prefer showing the exact commands they'd need
to run themselves over assuming they know the equivalent.

## This machine

- Laptop, 4 cores, **7.5GB RAM**, no swap by default, btrfs root (`/`).
- Panel: eDP-1, 1920x1080, scale **1.5** (set in `config/hypr/user.conf`).
- This is a forked, personalized copy of a friend's (Vitalii's) config —
  originally built and tuned for *his* machine (~32GB RAM, 4K monitor,
  NVIDIA). Don't assume upstream's defaults fit this box; several already
  had to be dialed back (see below).

## Repo vs. system config — where to make a change

- **`nixos/*.nix`** (packages, services, hardware, users) → edit in this
  repo, then `./install.sh` (does `nixos-rebuild switch` + relinks dotfiles).
  Never hand-edit `/etc/nixos` — it's not used; everything points at this
  flake.
- **Plain dotfiles** (`config/hypr/user.conf`, kitty, rofi, wayle) → symlinked
  live by `link.sh`. Edit directly in the repo, takes effect immediately (or
  after an app-specific reload, e.g. `hyprctl reload`, `wayle panel
  restart`) — **no `./install.sh` needed.**
- **home-manager-managed dotfiles** (git config, mc, kde theming — see
  `nixos/home/*.nix`) → these land as **read-only symlinks into the Nix
  store**. You cannot hand-edit `~/.gitconfig` etc. directly (learned this
  the hard way: `git config --global` failed with "Read-only file system").
  Change the source in `nixos/home/*.nix`, then `./install.sh`.

## Low-RAM tuning already applied — don't casually revert

`nixos/configuration.nix` has `max-jobs = 1` and `cores = 2` (not upstream's
`max-jobs = "auto"`, `cores = 0`). Upstream's setting OOM-killed the `nix`
process outright and froze the desktop on this machine (confirmed via
`dmesg`/kernel OOM logs) building the `br` from-source Rust overlay package.
If pulling upstream changes ever touches this block, keep the capped values
unless the machine's RAM situation has actually changed.

## Git remotes

- `origin` → the user's own fork, `git@github.com:CodeSpartan/simple_nix.git`
  (SSH, `gh` authenticated as `CodeSpartan`).
- `upstream` → Vitalii's original repo,
  `https://github.com/Lallapallooza/simple_nix.git` (HTTPS, read-only in
  practice — pull fixes from here, don't push).
- To pull a specific upstream fix: `git fetch upstream`, check
  `git log HEAD..upstream/main`, and prefer `git checkout upstream/main --
  <path>` for isolated files over a full merge — this fork's `host.nix`,
  `hardware.nix`, `security.nix`, and `hypr/user.conf` are heavily
  machine-specific and diverge from upstream on purpose (nvidia off,
  lanzaboote off, no nordvpn, different scale/username/secrets). A blind
  merge/pull will clobber them.
- When sending a PR **upstream**: build it in a clean `git worktree` off
  `upstream/main`, not off this dirty working tree — the working tree is
  full of personal machine config that must never leak into a PR to Vitalii.

## Secrets (agenix)

Personal age key at `~/.config/age/keys.txt` (public key documented in
`nixos/secrets/secrets.nix`). No secrets configured yet — add one with
`./scripts/add-secret.sh <name>`. Vitalii's original GitHub/AWS/OpenRouter
secrets were deliberately removed (this machine has no key that can decrypt
them, and they aren't this user's credentials to hold).

## iVPN — do not touch without explicit permission

The user manages their iVPN connection state (connect/disconnect/server/
protocol) themselves. **Never run `ivpn connect`/`disconnect`/etc. on your
own initiative**, even to test something — disconnecting it once already
caused a scare (briefly left the firewall/kill-switch disabled). If a fix
requires touching VPN settings, ask first and let the user do it, or get
explicit sign-off before running the command yourself.

## AI tools

`claude` and `codex` are installed natively via `scripts/install-ai-tools.sh`
into `~/.local/bin` — **not** part of the Nix rebuild (they update too often
to justify an OS rebuild per bump). Run once; `claude` self-updates after
that. No need to suggest rerunning it after every reboot/update.

## Debugging the live desktop session

This session's Bash tool can actually reach the real Hyprland/Wayland
session (same user, same machine) — useful for debugging visually instead of
guessing:
```bash
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1   # confirm via: ls /run/user/1000 | grep wayland
grim /tmp/.../screenshot.png       # then Read the file to see it
```
Wayle's own logs are very informative when something "looks wrong" instead
of crashing outright: `~/.local/state/wayle/wayle-shell.<date>.log`.

`sudo` and `gh auth login` (and anything else needing an interactive
password/browser prompt) **cannot** be run from this tool — they need a
terminal the user is actually watching. Hand those back with exact commands
rather than attempting them.

## `~/Desktop/message to vitalii.txt`

A running, brief log of genuine upstream-worthy findings (bugs, doc gaps,
things that'd bite the next person cloning this repo) discovered while using
this fork — for relaying back to Vitalii. Keep it updated when something
like that comes up, but keep entries short and don't pad it with
machine-specific or already-fixed/personal-preference stuff.

## Claude Code statusline

Configured in `~/.claude/settings.json` (global, not part of this repo):
reset countdown, quota % used, session tokens (fresh tokens only, excludes
cheap cache-reads). Route further tweaks through the `statusline-setup`
agent.
