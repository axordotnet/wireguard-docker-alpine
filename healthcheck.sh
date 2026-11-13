#!/bin/sh
set -eu
wg show wg-proxy >/dev/null 2>&1 || exit 1
target=${WG_HEALTHCHECK_TARGET:-}
[ -n "$target" ] || exit 0
# Accept IP literals only. Never accept flags or resolve names outside the tunnel.
case "$target" in
  *:* ) family=-6 ;;
  * ) family=-4 ;;
esac
printf '%s\n' "$target" | grep -Eq '^[0-9a-fA-F:.]+$' || exit 1
ip "$family" route get "$target" | grep -Eq 'dev wg-proxy( |$)' || exit 1
ping "$family" -c 1 -W 2 "$target" >/dev/null 2>&1
