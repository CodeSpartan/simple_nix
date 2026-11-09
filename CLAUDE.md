# CLAUDE.md

Guidance for Claude Code when working in this repo / on this machine.

## Who's using this

The user is a **first-time Linux user** (first NixOS install; before that only
Ubuntu-on-a-server through Claude). Don't assume Linux/Nix familiarity
(sudo, systemd, symlinks...). Explain what a command does, and give the exact
commands they'd run themselves.

They program but don't do ML (yet). The CUDA/cuDNN/Nsight/Jupyter stack
inherited from Vitalii stays -- don't trim it.

## This machine

- Desktop: Ryzen 9 3900X, 32GB, RTX 4080 SUPER, btrfs root. Fork of a friend's
  (Vitalii's) config for a similar box, so upstream defaults (`nvidia = true`,
  `cores = 0`, `linuxPackages_latest`, ...) fit. The old laptop is retired --
  ignore "weak hardware" leftovers.
- **MSI** board (AMI firmware), not the ASRock the README's BIOS steps describe.
- Monitor LG ULTRAGEAR+ 4K@144, scale 2 (`config/hypr/user.lua`). Calibration
  `config/hypr/lg-ultragear-srgb-d65.icm` (for the monitor's sRGB mode) is
  **not** given to Hyprland as `icc` -- Hyprland's ICC path crushes shadows.
  Instead `vcgt-loader` (`nixos/pkgs/vcgt-loader/`, autostarted in `user.lua`)
  loads just its calibration curve into the GPU gamma table; it must keep
  running. If `icc` is ever set and removed, Hyprland refuses gamma control
  ("gamma ramps in use") until restarted.
- Ethernet `enp35s0` in use. `eno1`'s driver `alx` is blacklisted (see Wayle).
  Wifi `iwlwifi` stays enabled on purpose.

## TODO

- After WoW: Forever launches (2026-11-04): WoW (not Battle.net) should
  bypass both VPNs. iVPN is done (`wow.exe` in `config/ivpn-bypass/apps`) --
  confirm with `journalctl -u ivpn-bypass` while WoW runs. v2rayN can't tell
  Wine programs apart (same exe for all), so: with the user in-game, read
  `curl 127.0.0.1:10814/connections` for WoW's server IPs/ports, propose a
  direct rule by destination, and add it only with the user's OK (back up
  `guiNDB.db` first; user clicks Reload).
- `config/hypr/user.conf` is dead (see Hyprland) -- could be deleted.
- From ~2026-12: check if the `discord-openh264` user unit (`nixos/home/apps.nix`)
  is still needed. It's a workaround for a Discord bug (deletes OpenH264 2.5.1
  at startup but its voice engine still loads it -> streams error 2012).
  Check: disable the path unit, restart Discord, watch a stream; Discord's log
  `logs/discord-webrtc_0` shows which `libopenh264-*` it loads. If it now loads
  a version it keeps, remove the unit.
- NvChad PR https://github.com/NvChad/ui/pull/564 (tabufline O(n^2) with
  many buffers). Check at most once a month: `gh pr view 564 -R nvchad/ui`.
  **Last checked: 2026-10-31** (just opened) -- update the date each check.
  Once merged: `:Lazy update ui` in nvim (bumps `config/nvim/lazy-lock.json`).
  Keep our module (`config/nvim/lua/configs/tabufline_buffers.lua`, wired
  via `ui.tabufline.modules` in `chadrc.lua`) anyway: it also keeps one tab
  visible after the current one when the bar scrolls (user wants that;
  upstream doesn't do it). Drop it only if upstream gains that too.

## Where to make a change

- **`nixos/*.nix`** → edit here, then `./install.sh` (rebuild + `link.sh` +
  flatpak update). `/etc/nixos` is unused; ignore it.
- **Plain dotfiles** (`config/hypr/user.lua`, kitty, rofi, wayle, ...) are
  symlinked live by `link.sh` -- reload the app (`hyprctl reload`,
  `wayle panel restart`), no rebuild.
- **home-manager files** (`nixos/home/*.nix`: git/ssh config, mc, KDE theming)
  are read-only Nix store links -- change the source, then `./install.sh`.
- **Configs the app rewrites itself** (KClock, VS Code, Claude Code
  settings): don't symlink -- `link.sh` sets only our keys (`kwriteconfig6`
  for KDE files, `jq` merge for JSON). Copy-once seeding (nomacs) when only
  starting defaults matter.
- Kernel-module blacklists apply only at boot. A rebuilt app keeps running the
  old binary until restarted.

## install.sh

- `nixos-rebuild` exit **4** (new generation active, some unrelated unit
  failed) is tolerated on purpose; anything else aborts. If dotfiles look
  missing after a rebuild, run `./link.sh`.
- It stages the gitignored `nixos/hardware-configuration.nix` for the flake;
  after an aborted run check `git status` so it isn't committed.
- Never `sudo ./install.sh` -- it calls sudo itself; as root it leaves
  root-owned files in `.git` (fix: `sudo chown -R vervain:users ~/code/simple_nix`).
- Discord exists as both system (managed by install.sh) and user Flatpak --
  leave both.
- install.sh updates only *system* Flatpaks. The rest: `update-messengers.sh`
  (all user Flatpaks = MAX, user Discord; skips MAX with a warning if
  `download.max.ru` is unreachable, i.e. on iVPN), `update-ai.sh`
  (claude/codex), `update-crafts.sh` (see Craft apps). `update-apps.sh` runs
  all three. No sudo, closes nothing; shared summary in `scripts/update-lib.sh`.

## Hyprland

- Real config is `config/hypr/user.lua` (`~/.config/hypr/hyprland.lua` just
  `dofile`s it). `hyprctl keyword` doesn't work with the Lua config; use
  `hyprctl eval 'hl.config({...})'`.
- Ctrl+Shift layout switch is a **release** bind; a release bind on a modifier
  needs it in its own mask (`CTRL + SHIFT + Shift_L`).
- `wtype` keys never trigger Hyprland binds (and don't reach XWayland apps) --
  bind changes need a real keypress from the user.
- `suppress-maximize-events` blocks apps' own fullscreen requests; exempt apps
  in *that* rule's match (`negative:`), a later narrower rule doesn't override.
- `hl.dsp.dpms("on")` ignores the string and **toggles** -- use
  `hl.dsp.dpms({action="on"})` / `{action="off"}`. hypridle (autostarted)
  turns the monitor off after 15 min, no lock; blocked while a window is
  fullscreen (`idle_inhibit` rule, minus VLC) or VLC plays
  (`vlc-idle-inhibit.sh`: VLC 3 sends no inhibit on Wayland). The fullscreen
  rule only counts while the window's workspace is visible (tested); GameMode's
  own inhibit is off (`inhibit_screensaver = 0`) since it held the screen on
  for the idle Battle.net launcher. See locks:
  `systemd-inhibit --list`, `hyprctl clients -j` (`inhibitingIdle`). Log:
  `journalctl --user -t hypridle`. `mouse/key_press_enables_dpms` also wake
  the monitor. Once (2026-11-03) mouse input didn't wake it (dpms stayed 0,
  hypridle's log was /dev/null then). The user went to TTY2; Claude ran
  dpms on from there -- while the desktop's VT is inactive that's lost (dpms
  reports 1, screen black on return; monitor power-cycle fixed it). Run dpms
  on only with the desktop VT active. A 1-min off/on test woke fine.
  The monitor powers itself off when unused (its own power-saving feature,
  wanted) and that drops the DP link: on its return the output is
  unplugged/replugged (2026-11-05 16:42 with no dpms, 2026-11-06 01:45 on
  wake after 5 h). Qt apps log "There are no outputs". It broke VLC's
  fonts, hence `QT_FONT_DPI` in its wrapper (`programs.nix`).
- `hl.exec_cmd` strings starting with `[` are parsed as window rules -- use
  `test`, not `[ ]`.
- `initial_workspace_tracking = 2`: a window opens on the workspace its
  launching process started on. Apps started from the bar would land on the
  bar's workspace (1), so bar clicks launch through Hyprland: plain programs
  via `config/wayle/launch.sh <cmd>`, and `clock-open`/`calendar-open` do
  `hyprctl eval 'hl.exec_cmd(...)'` themselves.
- Per-window keyboard layout: `hyprland-per-window-layout`, config in
  `config/hyprland-per-window-layout/options.toml`. Kill it with
  `pkill -x hyprland-per-wi` (`pgrep/pkill -f` also matches your own shell --
  true for any app).

## Mouse

Logitech G300s, configured with Piper (settings live in the mouse's memory).
Pointer accel imitates Windows' "Enhance pointer precision": a custom curve in
`user.lua` generated by `scripts/windows-mouse-curve.py` (assumes 1000 Hz).
`sensitivity` does nothing with it -- regenerate the curve instead.

## Wayle (status bar)

- **`~/.config/wayle/local.toml` must exist** (outside git; template
  `config/wayle/local.toml.example`). If it's missing wayle drops the *whole*
  config and shows its stock bar.
- `alx` is blacklisted because wayle's network module picks the first
  ethernet device (`eno1`) and shows "Disconnected". Un-blacklisting brings
  that back (cosmetic).
- Weather is a custom module (`config/wayle/weather.sh`, MET Norway) because
  the built-in provider (open-meteo) is unreachable from here.
- WhatsApp tray icon: `whatsapp-tray` user service (`nixos/whatsapp-tray.nix`).
  WhatsApp Web exposes no unread count (title stays "WhatsApp Web", no app
  badge), so the red dot counts its notifications (body starts with
  `web.whatsapp.com`) and clears when its window gets focus. PWA id is
  hardcoded in `whatsapp-tray.py`.
- MAX tray icon: `max-tray` user service (`nixos/max-tray.nix`), preferred
  over MAX's own (hidden by `blacklist = ["max"]` in `config/wayle/config.toml`).
  Red dot = MAX's unread counter (`setTotalUnreadCounter`, muted chats
  excluded), read from the log the running MAX has open
  (`~/.var/app/ru.max.MAX/data/ONEME/logs/`); clears when read anywhere.
  Its menu's Quit SIGTERMs MAX, then `flatpak kill`s the sandbox: MAX's
  `max-service` outlives it, and new launches hand over to it and quit.
- Wayle doesn't notice edits to `config.toml` (it watches the symlink, not
  the repo file) -- restart it after changing it.
- Tray icons whose app reports SNI status "Passive" are hidden (our wayle
  patches `wayle-systray-*.patch`). Blueman is patched to go Passive while
  Bluetooth is off (`blueman-hide-when-off`); turn it on in Bluetooth Manager.
- Harmless: `missing field overFullscreen` log spam; two iVPN tray icons.
- Logs: `~/.local/state/wayle/wayle-shell.<date>.log`. Restart with
  `wayle panel restart`, not kill + relaunch.
- **From Claude's shell, don't `wayle panel restart`**: the new bar inherits
  Claude's bare env (no `TZDIR`, no `HYPRLAND_INSTANCE_SIGNATURE`) and apps
  it launches break. Use `wayle panel stop`, then
  `hyprctl eval 'hl.exec_cmd("wayle shell")'` (Hyprland's env).

## NVIDIA / kernel / power

- Kernel/driver pairing comes from `flake.lock`; if a nixpkgs bump breaks the
  `nvidia-open` build, suspect that pairing.
- **Resizable BAR must stay on in BIOS.** With it off, BAR1 was 256 MiB; on
  2026-11-05 the desktop froze (kernel alive, Ctrl+Alt+F2 dead) after
  `NVRM: dmaAllocMapping_GM107: can't alloc VA space for mapping` from
  `nvidia_drm`. Check: `nvidia-smi -q -d MEMORY | grep -A3 BAR1` (~16 GB).
  On such a freeze: Alt+SysRq+K, or REISUB (`kernel.sysrq = 1`).
- **Suspend kills the display** (Xid 13, hard reset). All sleep targets are
  masked in `hardware.nix` -- keep it that way.
- Log out must use `uwsm stop` (wayle's `dropdown-logout-command`);
  `loginctl terminate-session` kills SDDM's greeter too. In `user.lua` event
  handlers, don't query workspaces from `window.destroy` -- it crashes
  Hyprland at exit.
- After a hard reset an NTFS drive can be "dirty" and `/mnt/ddrive` is empty:
  `sudo nix-shell -p ntfs3g --run "ntfsfix -d /dev/<part>"`, then mount.
- Builds failing with "gzip: unexpected end of file" after a power cut:
  `sudo nix-store --verify --check-contents --repair`.

## Login screen (SDDM)

Theme `sddm-astronaut` with our colors/background via `themeConfig` in
`nixos/desktop.nix`. Its wallpaper `wallpapers/sddm-fevre-dream.jpg` is a
plain git file (unignored in `.gitignore`), not LFS: Nix would read an LFS
pointer. Preview without logging out: `sddm-greeter-qt6 --test-mode --theme
/run/current-system/sw/share/sddm/themes/sddm-astronaut-theme` (a tiled
window squashes the layout -- fullscreen it).

## Secure Boot (Lanzaboote, enabled)

If keys ever need re-enrolling on this MSI board: in BIOS Secure Boot → Key
Management, **"Provision Factory Default keys" must be Disabled** (otherwise
factory keys come back every boot); delete the PK to enter Setup Mode; exit
via Save Changes and Reset. `sbctl enroll-keys` "File is immutable" → `chattr
-i` the efivars. Windows boots via F11 at POST.

## Git

- `origin` = user's fork `git@github.com:CodeSpartan/simple_nix.git` (SSH
  only). `upstream` = Vitalii's `Lallapallooza/simple_nix` -- never push.
- Pull upstream by **cherry-pick**, never merge. `host.nix`, `hardware.nix`,
  `security.nix`, `secrets/`, `hypr/user.lua` diverge on purpose. Skip
  NordVPN, Razer, and his secrets.
- Upstream reviewed through **`de6e925`** (2026-10-29): everything up to it was
  picked, partly picked, or skipped. Next time only look at
  `git log --oneline de6e925..upstream/main`, then update this hash.
- Upstream PRs: build in a clean `git worktree` off `upstream/main`.
- HTTPS git from Claude's shell can pop a password dialog on the desktop --
  prefix `GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true`.
- `*.png` goes through Git LFS.

## AMD uProf / Nsight Graphics

Enabled (`host.nix`). Their downloads can't be fetched by Nix (vendor
login); copies live in `vendorDir` (`/mnt/ddrive/NixOS-installers`), which
`install.sh` re-adds to the store, and `system.extraDependencies` keeps them
from GC. A version bump = new download into that folder + version/hash in
the overlay. `AMDuProfPcm` doesn't support this CPU (desktop Zen 2).

## Secrets (agenix)

- Age key `~/.config/age/keys.txt` -- without it the secrets can't be
  decrypted on a reinstall; the user should keep a copy in a password manager.
- SSH keys for GitHub/GitLab are secrets, decrypted to `/run/agenix/`.
- Add with `./scripts/add-secret.sh <name>` (stdin). Never read private key
  material into context: generate to a file, pipe it in, shred the file.
- Never touch Vitalii's secrets (`vastai.age` etc.).

## iVPN -- do not touch without explicit permission

**Never run `ivpn connect`/`disconnect`/etc. on your own initiative**, even to
test -- disconnecting once left the kill-switch off. Ask first.

Per-app bypass: `nixos/ivpn-bypass.nix` moves programs listed in
`config/ivpn-bypass/apps` (re-read live) into iVPN's split-tunnel cgroup.
Logs: `journalctl -u ivpn-bypass`. Some hosts fail through the VPN exit
(e.g. crates.io API 403).

## v2rayN -- do not touch without explicit permission

Same rule: **never stop/restart it, toggle Tun/proxy, switch servers, or edit
its config/DB on your own initiative.** Reading logs and the sing-box API
(`curl 127.0.0.1:10814/connections`) is fine.

- Runs in Tun mode; its routing overrides the iVPN bypass while on, so it has
  its own direct-process list (kept by hand to match).
- Routing lives in `~/.local/share/v2rayN/guiConfigs/guiNDB.db` (back it up
  before editing; applies on the user's Reload). `guiNConfig.json` is
  rewritten by the app -- change those settings in the UI.
- Process rules match the exe name per socket (no child inheritance), so
  Electron apps need domain rules.
- `link.sh` links the Nix `xray`/`sing-box` into v2rayN's `bin/` -- don't use
  its in-app core update.

## Unreal Engine / MMOKit

- UE 5.8.4 is the prebuilt Linux zip in `~/code/UE`, run via nix-ld
  (`unrealRuntimeLibs` in `programs.nix`). Run the editor with
  `SDL_VIDEODRIVER=x11` (native Wayland puts its dialogs off-screen). Its
  scripts need `bash <script>` (no `/bin/bash`). The Epic launcher can't
  install UE on Linux.
- MMOKit: `~/code/MMOKit` (GitLab), remote `windows` = the D: copy.
- PersistenceServer stays on D: (`/mnt/ddrive/MMO_Kit_Creation/
  PersistenceServer`), built with `dotnet-sdk_8` into `bin-linux/` so
  Windows' `bin/` is untouched; its launcher shares Windows' `mmokit.db`. That
  repo needs `core.autocrlf=true`.

## Silmaril (MUD client)

`~/code/Silmaril` (Kotlin Compose + Jewel; its own CLAUDE.md has the Linux
notes). `programs.nix` adds JBR 25 (`/etc/jbr-25`; Jewel 0.42 is Java 25),
`silmaril-gradle <task>` (Gradle on JDK 21 + JBR 25 toolchain, libGL path for
skiko, `sun.java2d.uiScale` from `GDK_SCALE` since JBR 25 ignores it) and
`silmaril` (runs the `createReleaseDistributable` output). The app-menu
"Silmaril" is the native rewrite instead: `~/code/silmaril-native/launch.sh`
(the latest `cargo build --release` there; that repo's CLAUDE.md has the rest).
Its hover tooltips are XWayland dialogs titled `silmaril-tooltip`; the
`silmaril-tooltip` rule in `user.lua` stops them stealing focus. User data
`~/Documents/Silmaril` (repo `Silmaril-Config`), copied from Windows without logs.

## Bloodborne (bbport)

The Windows install on D: runs via Proton-GE (`~/.local/bin/bloodborne`);
saves are shared with Windows. Notes in
`/mnt/ddrive/Games/bb_cheat/CLAUDE.md`.
- Its launcher settings in the Proton prefix need `present_mode = Immediate`
  (FIFO halves FPS). DLSS works with `PROTON_ENABLE_NVAPI=1`.
- `scripts\mods.py` is patched for Wine (hard links instead of symlinks); the
  launcher's Update overwrites it and the cheat.
- Native Linux build: `~/code/bloodborne_pc` (no DLSS).

## Battle.net / WoW (Lutris)

- Battle.net = Lutris's "Battle.net" installer (Proton-GE via umu). Prefix
  `~/Games/battlenet`, Lutris config `~/.local/share/lutris/games/battlenet-*.yml`
  -- outside git, redo after a reinstall. App-menu "Battle.net" starts it
  through Lutris without the Lutris window.
- WoW is the Windows install on C: (`/mnt/cdrive/Games/World of Warcraft`,
  product `wowf` = WoW: Forever), shared with Windows. The prefix's
  `drive_c/Games` symlinks to `/mnt/cdrive/Games` so paths match the
  install's own records (`C:/Games/...`). "Locate" still didn't register it:
  its entry was copied from Windows' `C:\ProgramData\Battle.net\Agent\product.db`
  into the prefix's (protobuf; one top-level field 1 per game).
- 2x scale: Lutris rewrites the prefix DPI on every launch -- set it in Lutris
  (Configure → Runner options → Advanced → DPI 192), not in the registry.
- The login code ("Challenge") pop-up renders black under Wine, and resizing
  it crashes Battle.net. Confirm the login on account.battle.net in Brave.
- WoW opens fullscreen via the `wow-fullscreen` rule in `user.lua`; in-game
  Display Mode "Fullscreen (Windowed)" 3840x2160. Don't exempt WoW from
  `suppress-maximize-events`: allowed to (un)fullscreen itself, it dropped
  out in combat and the bar came back. Tiled, it adopts the tile's size.
- Cursor trapped in WoW / RMB camera swinging to the screen edge: Wine
  locks the cursor to a window that fills the screen, and after WoW leaves
  fullscreen (Super+F, or a monitor DP dropout resizing it) it sometimes keeps
  that stale lock (seen with an X pointer grab test, 2026-11-09). Not WoW's
  `ClipCursor` (0) nor its display mode. Fix: Super+arrow to another window,
  then back -- the lock is only held while WoW is focused. No logout needed.
- TBC Anniversary is `_anniversary_` in the same install (product
  `wow_anniversary`, exe `WowClassic.exe`): in the iVPN bypass list too;
  v2rayN's port rules (TCP 3724, UDP 29523 -> direct) cover every WoW.
- Addons: WowUp-CF (`nixos/pkgs/wowup-cf/`, a bumped copy of nixpkgs' --
  drop it once nixpkgs has >= 2.25.4). Its Lutris auto-detect looks for
  `~/.config/lutris/system.yml`, which our Lutris doesn't have, so the
  Forever install was added by hand to `wow_installations` in
  `~/.config/WowUpCf/preferences.json` (`clientType` 10 = Forever, `location`
  = `_forever_/Wow.exe`; edit only with WowUp closed -- it ignores SIGTERM,
  quit from its tray). Outside git; redo after a reinstall, or use Options
  → WoW Clients → Add New. Windows' CurseForge tracks the same folder.
- FPS counter: MangoHud via Lutris' "FPS counter (MangoHud)" toggle;
  per-exe configs in `config/MangoHud/` (`wine-Wow.conf`, `wine-WoWClassic.conf` =
  FPS only, top-left; `wine-Battle.net.conf` = hidden). NVIDIA's overlay is Windows-only.
- Tried and dropped (2026-11-05): Battle.net as a Steam non-Steam game
  (no better), and gamescope (display fine, but `--force-grab-cursor`
  bypasses our mouse curve). Keep Lutris.
- 2026-11-05 a `/reload` hit an ntfs3 error (`attr_set_size_ex`) and left
  3 WoW files on C: unreadable/undeletable from Linux. They're parked in
  `_forever_/WTF/Account/MELANG.broken` (the good files were copied to a new
  `MELANG`); delete that folder after a `chkdsk C: /f` in Windows.
  `ntfsck -n` (`ntfsprogs-plus`) also lists ~420 "Allocated/Data size is
  different with IDX/$FN" entries -- normal on Windows volumes, don't
  "repair" them with it.

## Brave

- Copied extensions show "corrupted"; **Repair wipes the extension's data** --
  back up `Local Extension Settings/<id>` first, restore with Brave closed.
- **Don't delete `Default/Sync Data/`** -- it also holds installed PWAs.
- Brave keeps running with no windows while a PWA is open: `pgrep -x brave`.
- Apps Brave opens inherit its wrapper's `LD_LIBRARY_PATH` (its own Qt/Wayland
  libs). If an app misbehaves only when opened from Brave, that's why (fix:
  wrap the app with `--unset LD_LIBRARY_PATH`, like `nomacsTuned`,
  `qbittorrentClean`).
- Windows fonts (incl. Tahoma) were copied into `~/.local/share/fonts/windows`
  -- outside git, redo after a reinstall.
- Ctrl+scroll over the tab bar switching tabs = Hyprland binds in `user.lua`.
- Userscripts are kept in `config/userscripts/`.
- Writing userscripts: Chromium 136+ ignores `--remote-debugging-port` on
  the real profile, so a separate dev Brave is used: launch via Hyprland
  `brave --user-data-dir=$HOME/.config/brave-dev --remote-debugging-port=9222
  --remote-debugging-address=127.0.0.1`, then read/drive pages over CDP
  (`curl 127.0.0.1:9222/json`; Python `websockets` via nix-shell). Its
  Tampermonkey has "Allow access to file URLs" on and loads scripts from the
  repo with `@require file:///...` (edits apply on page reload).
- `xiaomi-router-en.user.js`: English for the Chinese-only router admin
  (192.168.31.1, http and https). Dictionary-based; untranslated text stays Chinese on
  purpose. For a new page, collect its strings from the page source
  (`fetch(location.href)`), not the DOM (already partly translated).
  It also gives the login form a hidden `admin` username so Brave saves the
  password -- but only over http: Brave's Shields "Upgrade connections to
  HTTPS" is Disabled for the router, because on its self-signed https
  Brave turns the password manager off.

## Russian state CA (Mintsifry)

Some Russian sites need the "Russian Trusted" root + 2 sub CAs
(`nixos/certs/`, from gosuslugi.ru/landing/crt_linux). System trust via
`security.pki.certificateFiles`, Firefox via policy (both in `security.nix`),
Brave/Chrome via `~/.pki/nssdb` (`link.sh`, certutil) -- they show under
"Linux", not "Installed by you". Root valid to 2032 (only it matters;
sites send their sub CA themselves, so the 2027 expiry of the old one is harmless).

## Screenshot upload (Gyazo / Cloudinary)

`nixos/screenshot-upload.nix` + `nixos/pkgs/screenshot-upload/`. PrtSc is
Flameshot; Shift/Ctrl+PrtSc pipe `flameshot gui --raw` to
`screenshot-upload gyazo|cloudinary` (link -> clipboard + Brave). Also in
Flameshot's "Open with" and Dolphin's right-click "Upload to". Credentials:
agenix `gyazo-token` (access token) and `cloudinary`
(`cloudinary://key:secret@cloud`, signed upload).

## Calendar / day notes (replaces Rainlendar)

`nixos/calendar.nix`. calcurse in a `foot` window (`calendar-open`, from the
bar's clock/icon); data `~/.local/share/calcurse`. `calendar-notes`
(`nixos/pkgs/calendar-notes/`) queries `calcurse -Q` for the Wayle module and
a once-a-day notification (user unit `calendar-notes-notify`, at login +
08:00; stamp in `~/.local/state/calendar-notes/`). calcurse follows
`XDG_DATA_HOME`/`XDG_CONFIG_HOME`, not `HOME` -- override those when testing.
GNOME Calendar was tried and dropped as too heavy (user wants lightweight).
Rainlendar's original data: `/mnt/cdrive/Users/Delfosse/.rainlendar2/Default.ics`.

## Timer / stopwatch (KClock)

`nixos/clock.nix`. Click the time in the bar → `clock-open` → KClock's
Timers page (the date is a separate custom module that still opens calcurse).
`kclockd` runs the timers and rings until dismissed. Clicking the popup's
body stops it. The X needs `popup-close-behavior = "remove"` (default just
hides the popup) plus two notification patches in
`nixos/overlays/wayle-pr255-package.nix`: wayle dropped "never expires"
notifications from its list, and gave a resent notification a new id that
KClock doesn't listen for.
Its "timer running" notification is off: `link.sh` sets
`timerNotification=Never` in `~/.config/kclockrc` (KClock rewrites that file,
so only that key is set, not symlinked).

## Notepad++ tabs (Windows) in Neovim

The Windows Notepad++ session (portable install `D:\Progs\Notepad++`) was
converted for nvim: unsaved tabs became files in `~/Documents/npp-tabs`,
and auto-session's session for that folder lists them plus the real files
on C:/D:/E: in Notepad++'s tab order (`cd ~/Documents/npp-tabs && nvim`).
Untouched copy of the Notepad++ folder: `~/Documents/notepad++ from windows`.
~600 buffers made NvChad's tab bar take 1.5 s per redraw -- see the TODO.

## PhotoCraft / PdfCraft / WordCraft

One recipe for all three (`nixos/pkgs/storytold-craft/`, versions + hashes in
`programs.nix`): the official prebuilt tarballs, GPU/window libs on
`LD_LIBRARY_PATH`. Releases come every few days; `update-crafts.sh` checks
GitHub, writes version + hash (from `SHA256SUMS.txt`) into `programs.nix`
and commits it (not pushed); `./install.sh` installs.
WordCraft runs under XWayland on purpose (drag-and-drop), so its wrapper sets
`WINIT_X11_SCALE_FACTOR` (else half size). PDF and Markdown defaults are
pinned (Brave, glow) so these apps' MIME claims don't take them over.

## qBittorrent / NTFS writes

Downloads go to E: (`/mnt/edrive`, HDD). ntfs3 zero-fills a file up to any
write past its written part, so torrents stalled the whole desktop for
minutes. Fixes: NTFS drives mount with `sparse` (`hardware.nix`), and
qBittorrent's Options → Advanced → Disk IO type = **POSIX-compliant** (the
default memory-mapped mode `fallocate`s files, which ntfs3 zero-fills even
when sparse). Pre-allocate disk space stays off.

## Image viewer (nomacs)

Default for images (`nomacsTuned` + `xdg.mime.defaultApplications` in
`programs.nix`). nomacs rewrites `~/.config/nomacs/Image Lounge.conf` -- edit
it only while nomacs is closed. `config/nomacs/default.ini` seeds it on a
fresh install only.

## Flatpak

Apps are outside Nix (`flatpak install --user flathub <id>`). Discord is
Flatpak on purpose (nixpkgs build had screen-share bugs; Krisp). It runs
native Wayland (`discord-flags.conf` in `nixos/home/apps.nix`): under
XWayland, Hyprland cut images copied from it to 128 KB. The second
Discord (separate account) is `discord-ptb` from nixpkgs -- Flathub has no PTB. MAX messenger is
`ru.max.MAX`: it's in the iVPN bypass list; installing/updating it needs
`flatpak` added to that list *temporarily* (leaving it would bypass every
Flatpak app). MAX needs `flatpak override --user
--talk-name=org.freedesktop.Notifications ru.max.MAX` (not in Nix; redo after
a reinstall): without it, no popups and no tray icon of its own.

## Working from Claude's shell

- Reach the desktop: `export XDG_RUNTIME_DIR=/run/user/1000
  WAYLAND_DISPLAY=wayland-1`, then e.g. `grim <file>` to screenshot.
- `sudo`, `gh auth login` or anything needing a password/browser prompt can't
  run here -- hand the user the exact command (they can use the `!` prefix).
- Crash forensics: `journalctl --list-boots`, `journalctl -b -1`,
  `coredumpctl list`.
- `claude`/`codex` are in `~/.local/bin` (`scripts/install-ai-tools.sh`), not
  in the Nix rebuild.
- `~/Desktop/message to vitalii.txt`: short list of upstream-worthy findings
  for Vitalii. Keep it current, no machine-specific stuff.
