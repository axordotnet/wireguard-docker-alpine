# Maintenance and stable updates

Dependabot checks Docker and GitHub Actions daily. Review its PRs and merge only
with passing CI. The daily rebuild refreshes edge and installed APK packages;
it never updates production hosts or overwrites a stable version.

For a stable security update:
1. Review dependency PRs and the daily vulnerability reports.
2. Increment VERSION (patch for compatible security fixes).
3. Add docs/releases/vX.Y.Z.md and update CHANGELOG.md and the Compose image tag.
4. Open a PR, wait for the required test check, then squash-merge with the exact
   title release: vX.Y.Z.
5. The pipeline builds, tests both implementations, scans and publishes X.Y.Z.
   After anonymous pull verification it creates the Git tag and GitHub release.
6. Announce the version through release notes. Users explicitly pull/recreate.

Review stable release needs weekly, and promptly when a fixable serious
vulnerability is discovered. This is a maintainer procedure, not an automated
promise of releases or unattended merging. Enable GitHub failure notifications.
If publication succeeds but release creation fails, inspect the recorded digest
and rerun only the release job; do not rebuild or overwrite the version.

Retain previous stable digests for rollback. A Git SHA tag can change on daily
rebuilds because package contents change; use image digests for exact reproducibility.
