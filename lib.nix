{ lib, pkgs }:

with lib;

rec {
  mkContainer = container: let
    mounts = container.mounts;

    storePaths = map (removeSuffix "\n")
      (splitString "\n"
        (builtins.readFile (pkgs.stdenv.mkDerivation {
          name = "store-paths";
          buildInputs = [pkgs.perl];

          exportReferencesGraph =
            map (x: [("closure-" + baseNameOf x) x]) container.storePaths;

          buildCommand = "perl ${pkgs.pathsFromGraph} closure-* > $out";
        })));

    storeVolumes = map (v: "${v}:${v}") storePaths;
  in (filterAttrs (n: v: v != null && v != []) {
    image = container.image;
    volumes = storeVolumes ++ mounts;
    devices = container.devices;
    command = container.command;
    tty = container.tty;
    stdin_open = container.interactive;
    restart = container.restart;
    environment = container.env;
    user = "${container.uid}:${container.gid}";
    links = container.links;
    net = container.net;
    dns = container.dns;
    dns_search = container.dns;
    expose = container.expose;
    ports = container.ports;
    privileged = container.privileged;
    capAdd = container.capAdd;
    capDrop = container.capDrop;
  });

  mkCompose = config: mapAttrs' (name: container:
    nameValuePair container.name (mkContainer container)
  ) config.containers;
}
