{ config, pkgs, lib, ... }:

with lib;

let
  globalConfig = config;

  containerOptions = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable container";
    };

    name = mkOption {
      type = types.str;
      default = "";
      description = "Name of the container";
    };

    envName = mkOption {
      type = types.str;
      default = globalConfig.name;
      description = "Name of the environment";
    };

    image = mkOption {
      type = types.str;
      default = globalConfig.defaultImage;
      description = "Base image to use for container";
    };

    command = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Command to run to start container";
    };

    script = mkOption {
      type = types.lines;
      default = "";
      description = "Script to run in container";
    };

    restart = mkOption {
      type = types.enum ["no" "always"];
      default = "no";
      description = "Restart policy when container exists";
    };

    storePaths = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Store paths to mount in cointainer";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of packages to expose";
    };

    path = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Packages to put in a PATH";
    };

    mounts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Mounts in container";
    };

    volumesFrom = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Use volumes from containers";
    };

    env = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Environment variables to set";
    };

    uid = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Uid under which to run in container";
    };

    gid = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Gid under which to run in container";
    };

    links = mkOption {
      type = types.listOf types.str;
      description = "List of containers to link with";
      default = [];
    };

    net = mkOption {
      type = types.nullOr types.str;
      description = "Network to attach to";
      default = null;
    };

    dns = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = "Set custom dns servers";
      default = null;
    };

    dnsSearch = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = "Set custom search domains";
      default = null;
    };

    expose = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = "List of ports to expose to other containers";
      default = null;
    };

    ports = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = "List of ports to expose";
      default = null;
    };

    devices = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = "List of host devices to attach to cantainer";
      default = null;
    };

    tty = mkOption {
      type = types.bool;
      description = "Whether to allocate pseudo tty";
      default = false;
    };

    interactive = mkOption {
      type = types.bool;
      description = "Keep stdin open even if not attached";
      default = false;
    };

    privileged = mkOption {
      type = types.bool;
      description = "Whether to run in privileged mode";
      default = false;
    };

    mountStore = mkOption {
      type = types.bool;
      description = "Wheter to mount nix store";
      default = false;
    };

    capAdd = mkOption {
      type = types.listOf types.str;
      description = "List of capabilities to add";
      default = [];
    };

    capDrop = mkOption {
      type = types.listOf types.str;
      description = "List of capabilities to drop";
      default = [];
    };

    workdir = mkOption {
      type = types.nullOr types.path;
      description = "Set working directory";
      default = null;
    };

    shmSize = mkOption {
      type = types.str;
      description = "Size of shm";
      default = "64m";
    };

    routes = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Additional routes for container";
    };

    dnsContainer = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container to use for dns";
    };

    defaultRoute = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Container to use for default route";
    };
  };

  containerConfig = { name, config, ... }: {
    options = containerOptions // {
      sidecar = containerOptions;
    };

    config = mkMerge [{
      name = mkDefault name;
      sidecar.enable = mkDefault false;
      sidecar.net = mkDefault "container:${config.name}";
      storePaths = config.packages;
      path = config.packages;
    } (mkIf (config.path != []) {
      env.PATH = mkDefault (
        (makeSearchPath "bin" config.path) + ":" +
        (makeSearchPath "sbin" config.path)
      );
    }) (mkIf config.mountStore {
      env.NIX_REMOTE = "daemon";
    }) (mkIf (config.defaultRoute != null) {
      links = [config.defaultRoute];
      sidecar.enable = true;
      sidecar.capAdd = ["NET_ADMIN"];
      sidecar.script = ''
        DEFAULT_ROUTE=$(${pkgs.glibc.bin}/bin/getent hosts ${config.defaultRoute} | ${pkgs.gawk}/bin/awk '{ print $1 }')
        ip route replace default via $DEFAULT_ROUTE
      '';
      sidecar.mounts = ["/etc/nsswitch.conf:/etc/nsswitch.conf"];
    }) (mkIf (config.routes != []) {
      links = map (r: r.via) config.routes;
      sidecar.enable = true;
      sidecar.capAdd = ["NET_ADMIN"];
      sidecar.script = concatMapStrings (route: ''
        IP=$(${pkgs.glibc.bin}/bin/getent hosts ${route.via} | ${pkgs.gawk}/bin/awk '{ print $1 }')
        ${pkgs.iproute}/bin/ip route add ${route.to} via $IP
      '') config.routes;
      sidecar.mounts = ["/etc/nsswitch.conf:/etc/nsswitch.conf"];
    }) (mkIf (config.dnsContainer != null) {
      links = [config.dnsContainer];
      sidecar.enable = true;
      sidecar.capAdd = ["NET_ADMIN"];
      sidecar.script = ''
        DNS_SERVER=$(${pkgs.glibc.bin}/bin/getent hosts ${config.dnsContainer} | ${pkgs.gawk}/bin/awk '{ print $1 }')
        echo "nameserver $DNS_SERVER" > /etc/resolv.conf
      '';
      sidecar.mounts = ["/etc/nsswitch.conf:/etc/nsswitch.conf"];
    }) (mkIf (config.script != "") (let
      command = pkgs.writeScript "${globalConfig.name}-${config.name}-script" ''
        #!${pkgs.bash}/bin/bash
        ${config.script}
      '';
    in {
      storePaths = [command];
      inherit command;
    })) (mkIf (config.sidecar.script != "") (let
      command = pkgs.writeScript "${globalConfig.name}-${config.name}-script-sidecar" ''
        #!${pkgs.bash}/bin/bash
        ${config.sidecar.script}
      '';
    in {
      sidecar.storePaths = [command];
      sidecar.command = toString command;
    }))];
  };
in {
  options = {
    name = mkOption {
      type = types.str;
      description = "Name of the environment";
    };

    defaultImage = mkOption {
      type = types.str;
      default = "busybox";
    };

    preStart = mkOption {
      description = "Pre-start script";
      type = types.str;
      default = "";
    };

    postStart = mkOption {
      description = "Post start script";
      type = types.str;
      default = "";
    };

    postStop = mkOption {
      description = "Post stop script";
      type = types.str;
      default = "";
    };

    scripts = mkOption {
      description = "Scripts to make for sandbox";
      type = types.attrsOf types.package;
      default = [];
    };

    containers = mkOption {
      type = types.attrsOf types.optionSet;
      options = [containerConfig];
      description = "List of containers in environment";
    };
  };
}
