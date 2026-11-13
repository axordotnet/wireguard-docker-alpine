# WireGuard Docker Alpine

Lightweight Alpine image with WireGuard tools and wireguard-go userspace fallback.
This is a VPN tunnel container, not a VPN provider or an administration UI.

[Documentation française](docs/README.fr.md) · [Security](SECURITY.md) ·
[Contributing](CONTRIBUTING.md) · [Maintenance](docs/maintenance.md)

## Quick start

Linux Docker Engine, Docker Compose, NET_ADMIN and /dev/net/tun are required.
Published architecture: linux/amd64. No privileged mode or SYS_MODULE is needed.
Load any required host modules outside the container.

Copy wg-proxy.conf.example to wg-proxy.conf, generate your own keys and fill in
addresses, peer public key and endpoint. Protect the configuration with mode 0600.
Never commit private keys or real VPN configuration.

~~~sh
umask 077
test ! -e private.key || exit 1
docker run --rm --entrypoint wg ghcr.io/axordotnet/wireguard-docker-alpine:1.1.0 genkey > private.key
docker run --rm -i --entrypoint wg ghcr.io/axordotnet/wireguard-docker-alpine:1.1.0 pubkey < private.key > public.key
# Fill wg-proxy.conf using these keys and your actual peer settings.
chmod 600 wg-proxy.conf
docker compose config --quiet
docker compose pull
docker compose up -d --no-build
docker compose exec wireguard wg show wg-proxy
~~~

For local development use docker compose build instead of pulling.
Keep a previous image digest before upgrading. Roll back by selecting that digest
and recreating the container. The versioned image is preferred over edge.

## Runtime and implementation

The configuration path and interface name are /etc/wireguard/wg-proxy.conf and
wg-proxy. The default Compose uses host networking, which grants control over the
host network namespace. Review routes before starting, especially default routes.
For a proxy sidecar, use network_mode: service:proxy in a shared Compose project,
or container:PROXY_NAME across projects, with explicit startup/recreation ordering.

Set WG_IMPLEMENTATION to auto (default), kernel, or userspace.
Auto keeps upstream wg-quick detection; userspace explicitly starts wireguard-go
even on a host with kernel support. The build installs a small override at
wg-quick's upstream extension point and fails if that point disappears.

The root filesystem and configuration mount are read-only; /run and /tmp use tmpfs.
NET_ADMIN configures the tunnel. DAC_READ_SEARCH reads private configuration owned
by another host UID. Mount only required files. no-new-privileges is enabled.
Do not use SaveConfig with read-only mounts. DNS directives may require writable
resolver files; configure DNS externally. Hooks run privileged commands and must
be trusted; adapt any hooks requiring writable paths or additional capabilities.

## Health and connectivity

By default, health checks confirm interface presence, not a working peer.
To probe an IP address through the tunnel:

~~~sh
export WG_HEALTHCHECK_TARGET=10.90.0.2
docker compose -f compose.yaml -f compose.healthcheck.yaml up -d --no-build
~~~

Use your actual peer IPv4 or IPv6 address, reachable through wg-proxy and answering
ICMP. This optional profile adds NET_RAW. The check rejects routes outside the
tunnel. ICMP filtering can mark an otherwise usable tunnel unhealthy.
Docker health status alone does not restart a container. No kill switch is supplied.

## Tests, images and updates

CI checks shell syntax and ShellCheck, then runs real kernel and userspace tunnels:
IPv4/IPv6 traffic, implementation identity, graceful stop/restart, optional
connectivity probes and configuration/interface ownership failures.
The exact publication candidate is tested again and scanned before tags move.
Fixable HIGH/CRITICAL vulnerabilities block publication; SBOM and provenance
are attached. Anonymous download is verified.

~~~sh
docker build --pull --no-cache -t wireguard-test .
bash tests/tunnel.sh wireguard-test kernel
bash tests/tunnel.sh wireguard-test userspace
~~~

Tests use a disposable Linux host and subnet 172.30.90.0/24.
CI does not certify Synology DSM; no AXORLOGY validation has been performed.

Dependabot and uncached edge rebuilds run daily. Stable tags are not overwritten:
security fixes require a new patch release, following the maintenance procedure.
No host is updated automatically and dependency PRs are not automatically merged.

Repository code is MIT licensed; bundled software retains its upstream licenses.
Upstream: [WireGuard](https://www.wireguard.com/),
[wireguard-go](https://github.com/WireGuard/wireguard-go),
[Alpine](https://alpinelinux.org/).
