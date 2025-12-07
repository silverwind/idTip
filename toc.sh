#!/bin/bash
set -euo pipefail

function toc {
  VERSIONS="$(curl -s https://us.version.battle.net/v2/products/$1/versions | awk -F "|" '/^[a-z]{2}\|/{print $6}')"
  for VERSION in $VERSIONS; do
    VERSION="${VERSION%.*}"
    if [[ "$VERSION" == 1.* ]] || [[ "$VERSION" == 3.* ]]; then
      VERSION="${VERSION/./}"
    fi
    VERSION="${VERSION//./0}"
    echo "$VERSION"
  done
}

VERSION_STRING="$(echo -e \
  "$(toc "wow")\n" \
  "$(toc "wowt")\n" \
  "$(toc "wowxptr")\n" \
  "$(toc "wow_beta")\n" \
  "$(toc "wow_classic")\n" \
  "$(toc "wow_classic_beta")\n" \
  "$(toc "wow_classic_ptr")\n" \
  "$(toc "wow_classic_era")\n" \
  "$(toc "wow_classic_era_ptr")\n" \
  "$(toc "wow_classic_titan")\n" \
  | awk '{$1=$1};1' | sort -n | uniq | xargs | perl -p -e "s# #, #g")"

if [[ "$VERSION_STRING" =~ ^[0-9,\ ]+$ ]]; then
  perl -p -i -e "s|## Interface: .+|## Interface: $VERSION_STRING|" idTip.toc
  exit 0
else
  echo "'""$VERSION_STRING""' does not match expected format"
  exit 1
fi
