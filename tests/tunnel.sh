#!/usr/bin/env bash
set -euo pipefail
image="${1:-wireguard-test}"
tmp="$(mktemp -d)"
prefix="wg-test-$$"
network="$prefix-net"
a="$prefix-a"
b="$prefix-b"
cleanup() {
  docker rm -f "$a" "$b" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -rf -- "$tmp"
}
trap cleanup EXIT
umask 077
docker run --rm --entrypoint wg "$image" genkey > "$tmp/a.key"
docker run --rm --entrypoint wg "$image" genkey > "$tmp/b.key"
apub="$(docker run --rm -i --entrypoint wg "$image" pubkey < "$tmp/a.key")"
bpub="$(docker run --rm -i --entrypoint wg "$image" pubkey < "$tmp/b.key")"
mkdir "$tmp/a" "$tmp/b"
# Isolated network used only in the ephemeral CI runner.
docker network create --subnet 172.30.90.0/24 "$network" >/dev/null
for side in a b; do
  if [ "$side" = a ]; then
    address=10.90.0.1; peer=10.90.0.2; endpoint=172.30.90.3; public="$bpub"
  else
    address=10.90.0.2; peer=10.90.0.1; endpoint=172.30.90.2; public="$apub"
  fi
  {
    printf '[Interface]\nAddress = %s/32\nPrivateKey = ' "$address"
    cat "$tmp/$side.key"
    printf 'ListenPort = 51820\nMTU = 1380\n\n[Peer]\nPublicKey = %s\nAllowedIPs = %s/32\nEndpoint = %s:51820\nPersistentKeepalive = 1\n' "$public" "$peer" "$endpoint"
  } > "$tmp/$side/wg-proxy.conf"
done
test -c /dev/net/tun || sudo modprobe tun
docker run -d --name "$a" --network "$network" --ip 172.30.90.2 --cap-add NET_ADMIN --device /dev/net/tun -v "$tmp/a:/etc/wireguard:ro" "$image" >/dev/null
docker run -d --name "$b" --network "$network" --ip 172.30.90.3 --cap-add NET_ADMIN --device /dev/net/tun -v "$tmp/b:/etc/wireguard:ro" "$image" >/dev/null
passed=false
for attempt in $(seq 1 20); do
  if docker exec "$a" ping -c 1 -W 1 10.90.0.2 >/dev/null 2>&1; then passed=true; break; fi
  sleep 1
done
[ "$passed" = true ] || { echo 'Tunnel test failed'; exit 1; }
docker exec "$b" ping -c 1 -W 2 10.90.0.1 >/dev/null
docker stop --time 15 "$a" >/dev/null
test "$(docker inspect -f '{{.State.ExitCode}}' "$a")" = 0
echo 'Bidirectional tunnel and graceful stop passed.'
