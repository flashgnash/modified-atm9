path=https://raw.githubusercontent.com/flashgnash/modified-atm9/refs/heads/master/modpack/pack.toml

git -C $path pull

java -jar packwiz-installer-bootstrap.jar -g -s server $path/pack.toml
