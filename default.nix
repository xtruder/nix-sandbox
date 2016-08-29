{ pkgs ? import <nixpkgs> {}, configuration ? ./test.nix }:

with pkgs.lib;

with import ./lib.nix { inherit (pkgs) lib; inherit pkgs; };

let

  config = (evalModules {
    modules = [./options.nix configuration];
    args = { inherit pkgs; };
  }).config;

  compose = pkgs.stdenv.mkDerivation {
    name = "docker-compose.json";

    buildCommand = ''
      cp ${pkgs.writeText "docker-compose.json" (
        builtins.toJSON (mkCompose config)
      )} $out
    '';
  };

  startEnv = pkgs.writeScriptBin "${config.name}-start" ''
    #!${pkgs.bash}/bin/bash

    ${config.preStart}
    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} up -d $@
    ${config.postStart}
  '';

  stopEnv = pkgs.writeScriptBin "${config.name}-stop" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} stop
    ${config.postStop}
  '';

  runEnv = pkgs.writeScriptBin "${config.name}-run" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} run $1 ''${@:2}
  '';

  execEnv = pkgs.writeScriptBin "${config.name}-exec" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.docker}/bin/docker exec -ti ${config.name}_$1_1 ''${@:2}
  '';

  attachEnv = pkgs.writeScriptBin "${config.name}-attach" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.docker}/bin/docker attach ${config.name}_$1_1
  '';

  logsEnv = pkgs.writeScriptBin "${config.name}-logs" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} logs
  '';

  logEnv = pkgs.writeScriptBin "${config.name}-log" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.docker}/bin/docker logs -f ${config.name}_$1_1
  '';

  GST_PLUGIN_PATH = pkgs.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-libav ];
  GI_TYPELIB_PATH = pkgs.lib.makeSearchPathOutput "lib" "lib/girepository-1.0" [
    pkgs.gst_all_1.gstreamer
    pkgs.gst_all_1.gst-plugins-base
    pkgs.gst_all_1.gst-plugins-good
    pkgs.gst_all_1.gst-plugins-bad
    pkgs.gst_all_1.gst-libav ];

  xpraEnv = pkgs.writeScriptBin "${config.name}-xpra" ''
    #!${pkgs.bash}/bin/bash
    export GST_PLUGIN_SYSTEM_PATH=${GST_PLUGIN_PATH}
    export GST_PLUGIN_PATH=${GST_PLUGIN_PATH}
    export GST_PLUGIN_SYSTEM_PATH_1_0=${GST_PLUGIN_PATH}
    export GI_TYPELIB_PATH=${GI_TYPELIB_PATH}
    export PYTHONPATH="$PYTHONPATH:${pkgs.pythonPackages.netifaces}/lib/${pkgs.pythonPackages.python.libPrefix}/site-packages:${pkgs.pythonPackages.numpy}/lib/${pkgs.pythonPackages.python.libPrefix}/site-packages:${pkgs.pythonPackages.websockify}/lib/${pkgs.pythonPackages.python.libPrefix}/site-packages:${pkgs.pythonPackages.pygobject3.out}/lib/${pkgs.pythonPackages.python.libPrefix}/site-packages:${pkgs.pythonPackages.gst-python.out}/lib/${pkgs.pythonPackages.python.libPrefix}/site-packages"
    export XPRA_ALLOW_SOUND_LOOP=1

    export LD_LIBRARY_PATH="${pkgs.gnome.gtkglext}/lib:$LD_LIBRARY_PATH"

    xpra attach --encoding=rgb --compress=0 --speaker=on tcp:localhost:10000
  '';

in pkgs.buildEnv {
  name = "nix-sandbox-${config.name}";
  paths = [startEnv stopEnv runEnv execEnv attachEnv logsEnv logEnv xpraEnv];
}
