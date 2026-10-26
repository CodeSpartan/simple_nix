let
  # Personal age key (portable -- store the private key in your password manager,
  # and at ~/.config/age/keys.txt on any machine you want to bootstrap).
  # Generated with: nix-shell -p age --run "age-keygen -o ~/.config/age/keys.txt"
  vervain = "age1f4nrvtr637kwemkjltrul5lulv29f82dnm9ssprtpjmqv003s5wqyshljh";

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
  # No secrets yet -- id_ed25519_github.age/id_ed25519_gitlab.age from the
  # previous (retired) machine were encrypted for a lost age key and had to
  # be dropped; re-add with ./scripts/add-secret.sh <name>, which encrypts
  # for every key in this file and wires up nixos/security.nix automatically.
}
