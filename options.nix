{ config, pkgs, lib, ... }:

with lib;

let
  globalConfig = config;

  containerOptions = { name, config, ... }: {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable container";
      };

      name = mkOption {
        type = types.str;
        default = name;
        description = "Name of the container";
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
    };

    config = {
      storePaths = config.packages;
      path = config.packages;
      env.PATH = mkDefault (
        (makeSearchPath "bin" config.path) + ":" +
        (makeSearchPath "sbin" config.path)
      );
    };
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

    containers = mkOption {
      type = types.attrsOf types.optionSet;
      options = [containerOptions];
      description = "List of containers in environment";
    };
  };
}
