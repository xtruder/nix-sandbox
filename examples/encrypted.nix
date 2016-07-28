{ pkgs, config, lib, ... }:

with lib;

let
  user = "offlinehacker";
  group = "users";

  pkgsStdenv = pkgs.buildEnv {
    name = "pkgs-stdenv";
    paths = with pkgs; [
      coreutils
      utillinux
      procps
      inetutils
      stdenv
      strace
      gnugrep
      gnused

      file
      tree
      unrar
      curl
      wget
      zip
      unzip
      psmisc
      p7zip
      which
      readline
      git

      zsh
      oh-my-zsh
      vim_configurable
      vimPlugins.YouCompleteMe
    ];
    ignoreCollisions = true;
  };

  defaultOpts = {name, ... }: {
    mounts = [
      "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/ca-certificates.crt"
      "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt"
      "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-bundle.crt"
      "/etc/passwd:/etc/passwd"
      "/etc/localtime:/etc/localtime"
      "/etc/machine-id:/etc/machine-id"
      "$HOME/data/${config.name}/${name}:/home/${user}"
    ];
    workdir = "/home/${user}";
    uid=user;
    gid=group;
  };

  X11Opts = {
    storePaths = [pkgs.fontconfig.out];
    mounts = [
      "/tmp/.X11-unix:/tmp/.X11-unix"
      "${pkgs.fontconfig.out}/etc/fonts:/etc/fonts"
    ];
    env.DISPLAY="$DISPLAY";
  };
in {
  name = "someenv";

  preStart = ''
    if mountpoint -q $HOME/data/${config.name}; then
      echo "Environment already mounted"
    else
      echo "Mounting environment"
      mkdir -p $HOME/data/.crypt
      sudo ${pkgs.encfs}/bin/encfs --public $HOME/data/.crypt/${config.name} $HOME/data/${config.name}
    fi

    sudo chown ${user}:${group} $HOME/data/${config.name}
    ${concatStrings (mapAttrsToList (n: v: ''
      sudo mkdir -p $HOME/data/${config.name}/${v.name}
      sudo chown ${user}:${group} $HOME/data/${config.name}/${v.name}
    '') config.containers)}
  '';

  postStop = ''
    sudo umount $HOME/data/${config.name}
  '';

  containers.firefox = mkMerge [defaultOpts X11Opts {
    packages = [pkgs.firefox];
    command = "firefox";
  }];

  containers.dev = mkMerge [defaultOpts {
    packages = [pkgsStdenv];
    mounts = ["${pkgsStdenv}:/home/${user}/.nix-profile"];
    command = "zsh";
    tty = true;
    interactive = true;
  }];
}
