#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix-prefetch-github git jq

set -x -eu -o pipefail

cd $(dirname "${BASH_SOURCE[0]}")

rm -rf bcachefs-tools.git
git clone --depth=1 --bare "http://github.com/koverstreet/bcachefs-tools.git"
DATE=$(git --git-dir=bcachefs-tools.git log --date=short --pretty=format:%ad HEAD)
rm -rf bcachefs-tools.git

nix-prefetch-github koverstreet bcachefs-tools | jq --arg date $DATE '. + {date:$date}' > version.json
