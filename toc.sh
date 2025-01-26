#!/bin/bash
set -euo pipefail

function toc {
  local version="$(nc 'us.version.battle.net' 1119 <<< "v1/products/$1/versions" | awk -F'|' '/^us/{print $6}')"
  version="${version%.*}"
  if [[ "$version" == 1.* ]]; then
    version="${version/./}"
  fi
  version="${version//./0}"
  echo "$version"
}

VERSION_STRING="$(echo -e \
  "$(toc "wow")\n" \
  "$(toc "wowt")\n" \
  "$(toc "wowxptr")\n" \
  "$(toc "wow_classic")\n" \
  "$(toc "wow_classic_ptr")\n" \
  "$(toc "wow_classic_era")\n" \
  "$(toc "wow_classic_era_ptr")\n" | sort -n | xargs | perl -p -e 's# #, #g')"

perl -p -i -e "s|## Interface: .+|## Interface: $VERSION_STRING|" idTip.toc
