#!/bin/bash
set -euo pipefail

# every product, so the addon is not flagged out of date on any client. The Lua
# only targets the current retail, classic and anniversary lines.
PRODUCTS=(wow wowt wowxptr wow_beta wow_anniversary wow_classic wow_classic_beta wow_classic_ptr wow_classic_era wow_classic_era_ptr wow_classic_titan)

function toc {
  VERSIONS="$(curl -fsS "https://us.version.battle.net/v2/products/$1/versions" | awk -F "|" '/^[a-z]{2}\|/{print $6}')"
  if [[ -z "$VERSIONS" ]]; then
    echo "No versions found for $1" >&2
    exit 1
  fi
  for VERSION in $VERSIONS; do
    IFS=. read -r MAJOR MINOR PATCH _ <<< "$VERSION"
    echo "$((MAJOR * 10000 + MINOR * 100 + PATCH))"
  done
}

VERSION_STRING="$(
  { # in parallel, since the output is sorted anyway and each echo is one short write
    PIDS=()
    for PRODUCT in "${PRODUCTS[@]}"; do toc "$PRODUCT" & PIDS+=("$!"); done
    # a failed product must poison the list, or its version is silently dropped
    for PID in "${PIDS[@]}"; do wait "$PID" || echo FAILED; done
  } | sort -nu | paste -sd, - | sed "s|,|, |g"
)"

if [[ "$VERSION_STRING" =~ ^[0-9,\ ]+$ ]]; then
  perl -p -i -e "s|## Interface: .+|## Interface: $VERSION_STRING|" idTip.toc
  exit 0
else
  echo "'""$VERSION_STRING""' does not match expected format"
  exit 1
fi
