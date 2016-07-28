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
    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} up -d
    ${config.postStart}
  '';

  stopEnv = pkgs.writeScriptBin "${config.name}-stop" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} stop
    ${config.postStop}
  '';

  runEnv = pkgs.writeScriptBin "${config.name}-attach" ''
    #!${pkgs.bash}/bin/bash

    ${pkgs.pythonPackages.docker_compose}/bin/docker-compose -p ${config.name} -f ${compose} run $1
  '';

in pkgs.buildEnv {
  name = "nix-sandbox-${config.name}";
  paths = [startEnv stopEnv runEnv];
}
