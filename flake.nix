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

          installScript = pkgs.writeShellScript "atm9-install.sh" ''
            set -e
            cd ${serverDir}
            ${pkgs.wget}/bin/wget https://maven.minecraftforge.net/net/minecraftforge/forge/${cfg.forgeMinecraftVersion}-${cfg.forgeVersion}/forge-${cfg.forgeMinecraftVersion}-${cfg.forgeVersion}-installer.jar
            ${cfg.javaPackage}/bin/java -jar forge-${cfg.minecraftVersion}-${cfg.forgeVersion}-installer.jar --installServer
          '';
          updateScript = pkgs.writeShellScript "atm9-update.sh" ''
            set -e
            cd ${serverDir}
            ${cfg.javaPackage}/bin/java -jar packwiz-installer-bootstrap.jar -g -s server https://raw.githubusercontent.com/flashgnash/modified-atm9/refs/heads/master/modpack/pack.toml
          '';
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

            minecraftVersion = mkOption {
              type = types.str;
              default = "1.20.1";
            };
            forgeVersion = mkOption {
              type = types.str;
              default = "47.4.10";
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
                pkgs.wget
              ];

              preStart = ''
                if [ ! -f ${serverDir}/.installed ]; then
                  cp -r ${self}/server/. ${serverDir}/
                  chmod -R u+w ${serverDir}
                  ${installScript}
                  touch ${serverDir}/.installed
                fi

                ${updateScript}

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
                TimeoutStopSec = "60s";
                KillSignal = "SIGTERM";
              };
            };
          };
        };
    };
}
