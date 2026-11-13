# Contributing

Open a focused pull request against main. Describe the behavior changed and
how it was tested. Never commit WireGuard configurations, private keys or tokens.
Repository code is MIT licensed; bundled dependencies retain their own licenses.

On a disposable Linux host with Docker and a free 172.30.90.0/24 subnet:

~~~sh
sh -n entrypoint.sh
bash -n tests/tunnel.sh
shellcheck entrypoint.sh tests/tunnel.sh
docker compose config --quiet
docker build --pull --no-cache -t wireguard-test .
bash tests/tunnel.sh wireguard-test
~~~

CI tests a bidirectional tunnel, graceful shutdown and failure cases with the
hardened runtime options. Keep existing configurations and the wg-proxy interface
compatible. Platform-specific compatibility should also be tested on the relevant target environment.

Review Dependabot PRs and merge only after checks succeed. Major Alpine or Action
updates require review of upstream release notes. No automatic merging is enabled.
For releases create a new semantic Git tag (vX.Y.Z); never reuse a version.
