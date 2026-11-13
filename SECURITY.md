# Security policy

Only the newest release and current main receive fixes. Older image digests
are immutable snapshots and do not receive security updates.

## Report a vulnerability

Use GitHub private vulnerability reporting when enabled:
https://github.com/axordotnet/wireguard-docker-alpine/security/advisories/new
If unavailable, open an issue asking for a private reporting channel without
including exploit details, keys, configurations or personal network information.
Do not post secrets in public issues or logs.

## Threat model

This container configures a VPN interface and necessarily runs as root with
NET_ADMIN. Host networking gives it control of the host network namespace.
Use a dedicated container namespace when host access is unnecessary.
Never enable privileged or SYS_MODULE. Load host modules outside this image.

Mount only trusted configuration, read-only, mode 0600. wg-quick hooks execute
arbitrary commands with the container's network privileges and may appear in
logs. Keep secrets out of hooks, image layers, environment dumps and Git.
Do not use SaveConfig with read-only mounts. DNS directives are not supported.
The healthcheck checks interface presence, not remote reachability or a handshake.
This image provides no automatic kill switch. A failed tunnel can leave ordinary
routes usable; enforce any fail-closed requirements in a separately reviewed firewall.

## Supply chain and updates

Actions use immutable commit SHAs, tracked by Dependabot. Alpine patch versions
are explicit and tracked daily. Daily uncached builds refresh installed APK
packages, including base packages. All image vulnerabilities are reported;
fixable HIGH/CRITICAL findings block publication. Unfixed findings remain visible.
The exact candidate digest is scanned and tunnel-tested before public tags move.
SBOM and build provenance accompany images. They are not a security certification.

Version tags must not be moved. Use a new release for a correction, keep previous
digests for rollback, and deliberately pull/recreate containers after validation.
The workflow never updates production hosts. The host kernel and Docker daemon
remain the operator's responsibility, including kernel WireGuard security fixes.
