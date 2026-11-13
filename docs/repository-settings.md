# Repository administration

The JSON files under .github/rulesets are importable templates, not active settings.
Import main.json and release-tags.json under Settings > Rules > Rulesets.
They require PRs and the GitHub Actions test check, block force pushes/deletions,
and prevent existing release tags from changing. No bypass actor is included.
Zero approvals supports a solo maintainer while still requiring passing CI.

Also enable private vulnerability reporting, Dependabot alerts and security
updates, dependency graph, secret scanning and push protection where available.
Keep default Actions permissions read-only, and allow only necessary Actions.
Verify package visibility is public. Do not enable unrestricted auto-merge.
