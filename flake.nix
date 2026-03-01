{
  description = "ATM9 Minecraft Server";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs =
    { self, nixpkgs }:
    {
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.services.atm9-server;
        in
        {
          options.services.atm9-server = {
            enable = mkEnableOption "ATM9 server";
            configPath = mkOption {
              type = types.str;
              default = "/var/lib/atm9-config";
              description = "Path on host containing ops.json, whitelist.json, etc.";
            };
            port = mkOption {
              type = types.port;
              default = 25565;
            };
          };

          config = mkIf cfg.enable {
            virtualisation.oci-containers = {
              backend = "docker";
              containers.atm9-server = {
                image = "atm9-server:latest";
                autoStart = true;
                ports = [
                  "${toString cfg.port}:25565/tcp"
                  "${toString cfg.port}:25565/udp"
                ];
                volumes = [
                  "atm9-data:/server"
                  "${cfg.configPath}:/config:ro"
                ];
              };
            };
          };
        };

      packages.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;

          entrypoint = pkgs.writeShellScript "entrypoint.sh" ''
            set -e
            cd /server

            if [ ! -f /server/.installed ]; then
              bash install.sh
              touch /server/.installed
            fi

            bash update.sh

            for file in ops.json whitelist.json banned-players.json banned-ips.json server.properties; do
              if [ -f /config/$file ]; then
                rm -f /server/$file
                ln -sf /config/$file /server/$file
              fi
            done

            exec bash run.sh
          '';

          dockerImage = pkgs.dockerTools.buildLayeredImage {
            name = "atm9-server";
            tag = "latest";
            contents = [
              pkgs.jdk17
              pkgs.bash
              pkgs.coreutils
              pkgs.curl
            ];
            extraCommands = ''
              mkdir -p server
              cp -r ${self}/. server/
            '';
            config = {
              Entrypoint = [ "${entrypoint}" ];
              WorkingDir = "/server";
              ExposedPorts."25565/tcp" = { };
              ExposedPorts."25565/udp" = { };
            };
          };
        in
        {
          dockerImage = dockerImage;
          default = dockerImage;
        };
    };
}
