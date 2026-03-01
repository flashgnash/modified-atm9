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
          serverDir = "/srv/minecraft/${cfg.name}";
        in
        {
          options.services.atm9-server = {
            enable = mkEnableOption "ATM9 server";
            name = mkOption {
              type = types.str;
              default = "modified-atm9";
              description = "Server name, used as directory name under /srv/minecraft/";
            };
            configPath = mkOption {
              type = types.str;
              default = "/srv/minecraft/config";
              description = "Path containing shared ops.json, whitelist.json, etc.";
            };
            port = mkOption {
              type = types.port;
              default = 25565;
            };
            javaPackage = mkOption {
              type = types.package;
              default = pkgs.jdk17;
            };
          };

          config = mkIf cfg.enable {
            users.users.minecraft = {
              isSystemUser = true;
              group = "minecraft";
              home = serverDir;
              createHome = true;
            };
            users.groups.minecraft = { };

            systemd.services.atm9-server = {
              description = "ATM9 Minecraft Server (${cfg.name})";
              wantedBy = [ "multi-user.target" ];
              after = [ "network.target" ];

              path = [
                cfg.javaPackage
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
              ];

              preStart = ''
                # Copy server files into place if not already installed
                if [ ! -f ${serverDir}/.installed ]; then
                  cp -r ${self}/server/. ${serverDir}/
                  chmod -R u+w ${serverDir}
                  bash ${serverDir}/install.sh
                  touch ${serverDir}/.installed
                fi

                # Always update
                bash ${serverDir}/update.sh

                # Link shared config files
                for file in ops.json whitelist.json banned-players.json banned-ips.json; do
                  if [ -f ${cfg.configPath}/$file ]; then
                    ln -sf ${cfg.configPath}/$file ${serverDir}/$file
                  fi
                done
              '';

              script = ''
                exec bash ${serverDir}/run.sh
              '';

              serviceConfig = {
                User = "minecraft";
                Group = "minecraft";
                WorkingDirectory = serverDir;
                Restart = "always";
                RestartSec = "10s";
                # Give the server time to save on shutdown
                TimeoutStopSec = "60s";
                KillSignal = "SIGTERM";
              };
            };
          };
        };
    };
}
