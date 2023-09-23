#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git jq
set -euo pipefail

URL_BASE=https://evilpiepirate.org/git/bcachefs.git
VERSION=6.5

cd "$(dirname "${BASH_SOURCE[0]}")"

COMMIT=$(git ls-remote $URL_BASE HEAD | awk '{ print $1; }')

URL="$URL_BASE/rawdiff/?id=${COMMIT}&id2=v${VERSION}"

nix store prefetch-file --name bcachefs-${COMMIT}.diff --json $URL |  jq --arg c "$COMMIT" '{diffHash: .hash, commit: $c}' > bcachefs.json
