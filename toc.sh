#!/bin/bash
set -euo pipefail

function toc {
  local version="$(curl -fsSL "https://us.version.battle.net/v2/products/$1/versions" | awk -F "|" '/^'$2'/{print $6}')"
  version="${version%.*}"
  if [[ "$version" == 1.* ]] || [[ "$version" == 3.* ]]; then
    version="${version/./}"
  fi
  version="${version//./0}"
  echo "$version"
}

VERSION_STRING="$(echo -e \
  "$(toc "wow" "us")\n" \
  "$(toc "wowt" "us")\n" \
  "$(toc "wowxptr" "us")\n" \
  "$(toc "wow_beta" "us")\n" \
  "$(toc "wow_classic" "us")\n" \
  "$(toc "wow_classic_beta" "us")\n" \
  "$(toc "wow_classic_ptr" "us")\n" \
  "$(toc "wow_classic_era" "us")\n" \
  "$(toc "wow_classic_era_ptr" "us")\n" \
  "$(toc "wow_classic_titan" "cn")\n" \
  | awk '{$1=$1};1' | sort -n | uniq | xargs | perl -p -e "s# #, #g")"

if [[ "$VERSION_STRING" =~ ^[0-9,\ ]+$ ]]; then
  perl -p -i -e "s|## Interface: .+|## Interface: $VERSION_STRING|" idTip.toc
  exit 0
else
  echo "'""$VERSION_STRING""' does not match expected format"
  exit 1
fi
