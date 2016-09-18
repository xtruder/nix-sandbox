{ lib, pkgs }:

with lib;

rec {
  mkContainer = config: container: let
    mounts = container.mounts;

    storePaths = map (removeSuffix "\n") (filter (s: s != "")
      (splitString "\n"
        (builtins.readFile (pkgs.stdenv.mkDerivation {
          name = "store-paths";
          buildInputs = [pkgs.perl];

          exportReferencesGraph =
            map (x: [("closure-" + baseNameOf x) x]) container.storePaths;

          buildCommand = "perl ${pkgs.pathsFromGraph} closure-* > $out";
        }))));

    storeVolumes =
      if (container.mountStore)
      then ["/nix:/nix"]
      else map (v: "${v}:${v}:ro") storePaths;
  in (filterAttrs (n: v: v != null && v != [] && v!= "") {
    image = container.image;
    volumes = unique (storeVolumes ++ mounts);
    volumes_from = unique container.volumesFrom;
    devices = container.devices;
    command = container.command;
    tty = container.tty;
    stdin_open = container.interactive;
    restart = container.restart;
    environment = container.env;
    user = optionalString (container.uid != null && container.gid != null) "${container.uid}:${container.gid}";
    links = unique (flatten (map (name:
      if hasAttr name config.containers && config.containers.${name}.sidecar.enable
      then [name "${name}-sidecar"]
      else name
    ) container.links));
    net = container.net;
    dns = container.dns;
    dns_search = container.dns;
    expose = container.expose;
    ports = container.ports;
    privileged = container.privileged;
    cap_add = unique container.capAdd;
    cap_drop = unique container.capDrop;
    working_dir = container.workdir;
    shm_size = container.shmSize;
  });

  mkCompose = config: listToAttrs (flatten (mapAttrsToList (name: container:
    [(nameValuePair container.name (mkContainer config container))]
    ++ (optionals container.sidecar.enable
      [(nameValuePair "${container.name}-sidecar" (mkContainer config container.sidecar))])
  ) config.containers));
}
