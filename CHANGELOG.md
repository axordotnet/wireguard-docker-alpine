# Changelog

## 1.1.0 — 2026-11-13

- Explicit kernel/userspace selection, IPv4/IPv6 and restart regression tests.
- Optional tunnel connectivity healthcheck and English README.
- Versioned release workflow and documented stable security-update process.

- Upgrade Alpine from 3.22 to 3.24.4 and refresh installed packages on every build.
- Pin Actions to reviewed commit SHAs; check dependencies and rebuild daily.
- Scan and tunnel-test the exact publication candidate before promoting tags.
- Add read-only root filesystem, temporary runtime mounts and minimal capabilities.
- Add failure-case tests, ShellCheck, MIT license and contribution/security policies.

## 1.0.0

- Initial published WireGuard Alpine image for linux/amd64.
