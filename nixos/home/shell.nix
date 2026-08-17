{ config, pkgs, ... }:

{
  # SSH -- route GitHub/GitLab traffic through their agenix-managed keys.
  # IdentityFile points at the agenix decrypt path (/run/agenix/<name>), not a
  # plain ~/.ssh file -- the key only exists on disk as the encrypted .age
  # blob in the repo plus this tmpfs copy recreated on every activation.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      IdentityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_github";
    };
    settings."gitlab.com" = {
      IdentityFile = "/run/agenix/id_ed25519_gitlab";
    };
  };

  # Git -- rebase on pull and copy AuthorDate to CommitterDate during rebase so the
  # timeline on a rebased branch stays anchored to when the work was actually done.
  # autoSetupRemote makes the first push of a new branch create and track its remote
  # counterpart so bare `git push` works instead of demanding `git push -u origin <br>`.
  programs.git = {
    enable = true;
    lfs.enable = true;                 # Git Large File Storage for binaries (images, etc.)
    settings = {
      user.name = "CodeSpartan";
      user.email = "codespartan.supp@gmail.com";
      pull.rebase = true;
      rebase.committerDateIsAuthorDate = true;
      push.autoSetupRemote = true;
    };
  };

  # Zsh with oh-my-zsh and powerlevel10k prompt
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "z" "sudo" "extract" "command-not-found" "fzf" "docker" ];
    };
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initContent = ''
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # Alert on available upstream config updates
      if [[ -f ~/.local/state/nixos-update-available ]]; then
        printf '\e[1;33m%s\e[0m\n' "$(cat ~/.local/state/nixos-update-available)"
        rm -f ~/.local/state/nixos-update-available
      fi

      # Import SSH_AUTH_SOCK from systemd (gnome-keyring / gcr-ssh-agent)
      if [[ -z "$SSH_AUTH_SOCK" ]]; then
        for _sock in "$XDG_RUNTIME_DIR/gcr/ssh" "$XDG_RUNTIME_DIR/keyring/ssh"; do
          if [[ -S "$_sock" ]]; then export SSH_AUTH_SOCK="$_sock"; break; fi
        done
        unset _sock
      fi

      # Redirect "sudo vim/nvim <file>" to "sudoedit <file>" (safer, uses $EDITOR).
      # Only catches the simple case; "sudo -E vim" etc. bypass this.
      sudo() {
        if [[ "$1" == "vim" || "$1" == "nvim" ]]; then
          shift
          command sudoedit "$@"
        else
          command sudo "$@"
        fi
      }
    '';
  };
}
