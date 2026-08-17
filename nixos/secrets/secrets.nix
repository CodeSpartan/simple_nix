let
  # Personal age key (portable -- store the private key in your password manager,
  # and at ~/.config/age/keys.txt on any machine you want to bootstrap).
  # Generated with: nix-shell -p age --run "age-keygen -o ~/.config/age/keys.txt"
  ashberry = "age15c9kjwel5xuru7ex6qaquuj873k0eczw7qmyd7uc72rmd8c3ruuq8ctyzl";

  # Machine host key (for unattended decryption at boot).
  # Not known yet -- this machine hasn't been switched once, so
  # /etc/ssh/ssh_host_ed25519_key doesn't exist. After the first successful
  # `./install.sh`, run:
  #   cat /etc/ssh/ssh_host_ed25519_key.pub
  # and drop the ssh-ed25519 line in here, then re-encrypt any secrets:
  #   cd nixos/secrets && agenix -r -i ~/.config/age/keys.txt
  # nixos = "ssh-ed25519 AAAA...";
in
{
  # No secrets yet. Add one with ./scripts/add-secret.sh <name> -- it encrypts
  # for every key in this file and wires up nixos/security.nix automatically.
  "id_ed25519_gitlab.age".publicKeys = [ ashberry ];
  "id_ed25519_github.age".publicKeys = [ ashberry ];
}
