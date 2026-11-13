#!/usr/bin/env bash
set -euo pipefail
image="${1:-wireguard-test}"
mode="${2:-kernel}"
case "$mode" in kernel|userspace) ;; *) echo 'Expected kernel or userspace'; exit 1 ;; esac
tmp="$(mktemp -d)"
prefix="wg-test-$$"
hardening=(--read-only --cap-drop ALL --cap-add NET_ADMIN --cap-add DAC_READ_SEARCH --cap-add NET_RAW --security-opt no-new-privileges --tmpfs '/run:rw,noexec,nosuid,size=16m' --tmpfs '/tmp:rw,noexec,nosuid,size=16m')
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
    address=10.90.0.1; address6=fd90::1; peer6=fd90::2; peer=10.90.0.2; endpoint=172.30.90.3; public="$bpub"
  else
    address=10.90.0.2; address6=fd90::2; peer6=fd90::1; peer=10.90.0.1; endpoint=172.30.90.2; public="$apub"
  fi
  {
    printf '[Interface]\nAddress = %s/32, %s/128\nPrivateKey = ' "$address" "$address6"
    cat "$tmp/$side.key"
    printf 'ListenPort = 51820\nMTU = 1380\n\n[Peer]\nPublicKey = %s\nAllowedIPs = %s/32, %s/128\nEndpoint = %s:51820\nPersistentKeepalive = 1\n' "$public" "$peer" "$peer6" "$endpoint"
  } > "$tmp/$side/wg-proxy.conf"
done
test -c /dev/net/tun || sudo modprobe tun
docker run -d --name "$a" --network "$network" --ip 172.30.90.2 "${hardening[@]}" --device /dev/net/tun -e WG_IMPLEMENTATION="$mode" -v "$tmp/a:/etc/wireguard:ro" "$image" >/dev/null
docker run -d --name "$b" --network "$network" --ip 172.30.90.3 "${hardening[@]}" --device /dev/net/tun -e WG_IMPLEMENTATION="$mode" -v "$tmp/b:/etc/wireguard:ro" "$image" >/dev/null
# Preflight failures must exit cleanly without exposing configuration contents.
if docker run --rm "${hardening[@]}" "$image" >/dev/null 2>&1; then
  echo 'Missing configuration was accepted'; exit 1
fi
mkdir "$tmp/placeholder"
printf '[Interface]\nPrivateKey = REPLACE_ME\n' > "$tmp/placeholder/wg-proxy.conf"
if docker run --rm "${hardening[@]}" -v "$tmp/placeholder:/etc/wireguard:ro" "$image" >/dev/null 2>&1; then
  echo 'Placeholder configuration was accepted'; exit 1
fi
# Confirm that the selected implementation is really running.
for container in "$a" "$b"; do
  for _ in $(seq 1 20); do
    if docker exec "$container" wg show wg-proxy >/dev/null 2>&1; then break; fi
    sleep 1
  done
  if [ "$mode" = userspace ]; then
    docker exec "$container" test -S /run/wireguard/wg-proxy.sock
  else
    docker exec "$container" ip -details link show wg-proxy | grep -q wireguard
    docker exec "$container" sh -c 'test ! -S /run/wireguard/wg-proxy.sock'
  fi
done
passed=false
for _ in $(seq 1 20); do
  if docker run --rm --network "container:$a" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -c 1 -W 1 10.90.0.2 >/dev/null 2>&1; then passed=true; break; fi
  sleep 1
done
[ "$passed" = true ] || { echo 'Tunnel test failed'; docker logs "$a"; docker logs "$b"; exit 1; }
docker run --rm --network "container:$b" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -c 1 -W 2 10.90.0.1 >/dev/null
docker run --rm --network "container:$a" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -6 -c 1 -W 2 fd90::2 >/dev/null
docker run --rm --network "container:$b" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -6 -c 1 -W 2 fd90::1 >/dev/null
docker exec "$a" /usr/local/bin/wireguard-healthcheck
# Exercise the optional connectivity profile (NET_RAW enabled in this test).
docker exec -e WG_HEALTHCHECK_TARGET=10.90.0.2 "$a" /usr/local/bin/wireguard-healthcheck
if docker exec -e WG_HEALTHCHECK_TARGET=127.0.0.1 "$a" /usr/local/bin/wireguard-healthcheck; then
  echo 'Healthcheck accepted an address outside the tunnel'; exit 1
fi
# A second instance must not take over or delete the existing shared interface.
if docker run --rm --network "container:$a" "${hardening[@]}" -v "$tmp/a:/etc/wireguard:ro" "$image" >/dev/null 2>&1; then
  echo 'Existing interface was accepted'; exit 1
fi
docker exec "$a" wg show wg-proxy >/dev/null
docker stop --time 15 "$a" >/dev/null
test "$(docker inspect -f '{{.State.ExitCode}}' "$a")" = 0
docker start "$a" >/dev/null
recovered=false
for _ in $(seq 1 20); do
  if docker run --rm --network "container:$a" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -c 1 -W 1 10.90.0.2 >/dev/null 2>&1; then recovered=true; break; fi
  sleep 1
done
[ "$recovered" = true ] || { docker logs "$a"; exit 1; }
docker run --rm --network "container:$a" --cap-drop ALL --cap-add NET_RAW --entrypoint ping "$image" -6 -c 1 -W 2 fd90::2 >/dev/null
echo "IPv4/IPv6 tunnel, healthcheck, graceful stop and restart passed ($mode)."
