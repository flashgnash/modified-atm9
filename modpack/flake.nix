{
  description = "Packwiz";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs =
    { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      addmr = pkgs.writeShellApplication {
        name = "addmr";
        text = ''
          #!/usr/bin/env bash
          packwiz mr add "$@"
        '';
      };

      addcf = pkgs.writeShellApplication {
        name = "addcf";
        text = ''
          #!/usr/bin/env bash
          packwiz cf add "$@"
        '';
      };

      addmod = pkgs.writeShellApplication {
        name = "addmod";
        text = ''
          #!/usr/bin/env bash
          mod="$1"
          if [ -z "$mod" ]; then
            echo "Usage: addmod <modname>"
            exit 1
          fi
          if ! packwiz mr add "$mod"; then
            read -rp "Not found on modrinth. Try curseforge? [y/N]: " yn
            case "$yn" in
              [Yy]*) packwiz cf add "$mod" ;;
            esac
          fi
        '';
      };

      addmods = pkgs.writeShellApplication {
        name = "addmods";
        text = ''
          #!/usr/bin/env bash
          while true; do
            read -rp "Mod name (blank to stop): " mod
            [ -z "$mod" ] && break
            addmod "$mod"
          done
        '';
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.packwiz
          addmr
          addcf
          addmod
          addmods
        ];
      };
    };
}
