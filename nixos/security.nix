{ lib, pkgs, host, ... }:

let
  # Common ownership for user-scoped secrets
  userSecret = {
    owner = host.username;
    group = "users";
    mode = "0600";
  };

  # Russian state CA, see below
  russianCAs = [
    ./certs/Russian_Trusted_Root_CA.cer
    ./certs/Russian_Trusted_Sub_CA.cer
    ./certs/Russian_Trusted_Sub_CA_2024.cer
  ];
in
{
  # --- Keyring ---
  # gnome-keyring for storing secrets (Brave sync, SSH keys, etc.) -- kwallet disabled
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.sddm.enableKwallet = lib.mkForce false;
  security.pam.services.login.enableKwallet = lib.mkForce false;

  # PAM service for hyprlock -- without this, hyprlock can't authenticate to unlock
  security.pam.services.hyprlock = {};

  # --- Sudo ---
  # NixOS does not include /etc/sudoers.d by default; the directive below makes
  # sudo read drop-in rules from it. Used by scripts/setup_profiling.sh to install
  # a session-scoped NOPASSWD rule for BCC tools, removed on --reset.
  security.sudo.extraConfig = ''
    @includedir /etc/sudoers.d
  '';

  # --- SSH ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ host.username ];
    };
    extraConfig = "MaxAuthTries 3";
  };

  # --- Secrets (agenix) ---
  # age-encrypted files decrypted at activation time.
  # Tries host SSH key first, falls back to personal age key (for new machine bootstrap).
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "${host.homeDir}/.config/age/keys.txt"
  ];

  # No secrets configured yet -- the original owner's GitHub/AWS/OpenRouter
  # secrets were dropped (this machine has no key that can decrypt them, and
  # they aren't this machine's credentials to hold). Add your own with:
  #   ./scripts/add-secret.sh my-secret-name
  # which encrypts the value, adds it to nixos/secrets/secrets.nix, and wires
  # up an `age.secrets.<name>` block here automatically. See README > Secrets.

  # --- Firewall ---
  # NixOS enables firewall by default; make policy explicit
  age.secrets.id_ed25519_github = {
    file = ./secrets/id_ed25519_github.age;
    owner = host.username;
    group = "users";
    mode = "0600";
  };
  age.secrets.id_ed25519_gitlab = {
    file = ./secrets/id_ed25519_gitlab.age;
    owner = host.username;
    group = "users";
    mode = "0600";
  };
  age.secrets.gyazo-token = {
    file = ./secrets/gyazo-token.age;
    owner = host.username;
    group = "users";
    mode = "0600";
  };
  age.secrets.cloudinary = {
    file = ./secrets/cloudinary.age;
    owner = host.username;
    group = "users";
    mode = "0600";
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ];   # openssh module auto-opens 22
    allowedUDPPorts = [ ];
  };

  # --- System Health ---
  services.earlyoom.enable = true;      # Kill runaway processes before OOM freezes the desktop
  services.journald.settings.Journal.SystemMaxUse = "500M";   # Cap journal logs (default is ~4GB)

  # --- Russian state CA (Ministry of Digital Development) ---
  # Some Russian sites (banks, gov) use certificates from this CA. Files from
  # https://www.gosuslugi.ru/landing/crt_linux. Browsers don't read this system
  # list for extra roots: Brave and Chrome share ~/.pki/nssdb (link.sh adds
  # them there with certutil), Firefox gets them from the policy below.
  # Russian_Trusted_Sub_CA.cer expires 2027-03-06; fetch a fresh set before then.
  security.pki.certificateFiles = russianCAs;
  programs.firefox.policies.Certificates.Install = map toString russianCAs;
  environment.systemPackages = [ pkgs.nssTools ];   # certutil, used by link.sh
}
