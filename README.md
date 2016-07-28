# Nix-sandbox

Sandbox that uses [nix](https://nixos.org/nix) as package manager and
[docker](https://www.docker.com/) as container manager

## Dependencies

- nix package manager
- docker

## Build sandbox environment

    $ nix-build --arg configuration ./env.nix

## Start sandbox environment

    $ <name>-start
    $ <name>-stop
    $ <name>-attach CONTAINER_NAME
    $ <name>-run CONTAINER_NAME [COMMAND]

## Configuration examples

Look into examples folder

## Author

Jaka Hudoklin <jakahudoklin@gmail.com> for
[ProteusLabs](https://github.com/proteuslabs)

## License

MIT
