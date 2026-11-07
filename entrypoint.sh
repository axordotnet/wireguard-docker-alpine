#!/bin/sh
set -eu
config=/etc/wireguard/wg-proxy.conf
test -s "$config" || { echo 'Missing /etc/wireguard/wg-proxy.conf' >&2; exit 1; }
if grep -Eq 'REMPLACER_|REPLACE_' "$config"; then
  echo 'Replace configuration placeholders before starting.' >&2
  exit 1
fi
# Never take over an existing interface in a shared network namespace.
if ip link show wg-proxy >/dev/null 2>&1; then
  echo 'Interface wg-proxy already exists; refusing to take it over.' >&2
  exit 1
fi
cleanup() {
  wg-quick down "$config" || true
}
wg-quick up "$config"
trap 'exit 0' TERM INT
trap cleanup EXIT
while wg show wg-proxy >/dev/null 2>&1; do
  sleep 5 &
  wait $! || true
done
exit 1
