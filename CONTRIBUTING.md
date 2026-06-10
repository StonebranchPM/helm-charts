# Contributing

Thank you for improving these Helm charts.

## Prerequisites

Install the pinned toolchain before making changes:

```bash
make bootstrap
```

This installs helm, chart-testing (ct), kind, kubectl, helm-docs, kubeconform,
kube-score, yamllint, and the helm-unittest plugin at the versions locked in
`scripts/bootstrap.sh`.

## Workflow

1. Fork the repo and create a branch from `main`.
2. Make changes inside the relevant chart directory.
3. Run the full verification gate before committing:
   ```bash
   make verify
   ```
4. If template output changed intentionally, update the golden snapshots:
   ```bash
   make golden-update
   git add tests/golden/
   ```
5. Open a pull request targeting `main`. One milestone per PR (see
   [docs/ROADMAP.md](docs/ROADMAP.md) for the phase breakdown).

## Commit message format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(ua):  add NetworkPolicy support to UA chart
fix(uac):  correct OMS configmap key for UAGNETNAME
docs:      update README quickstart
chore:     bump helm-docs to 1.14.2 in bootstrap.sh
```

Scope matches the affected component: `ua`, `uac`, `native`, `ocp`, `aks`, `ci`,
`docs`, or `chore`.

## What belongs in a PR description

- Which ROADMAP.md success criteria this PR advances (check the boxes)
- Actual output of `make verify` (paste, don't summarise)
- For template changes: `make golden` diff or explicit `golden-update` note
- For milestone PRs: smoke test results per platform, or explicit "NOT TESTED on X"

## Hard rules

- Never embed credentials or secrets in chart templates — use the `existingSecret`
  pattern or reference a pre-created Kubernetes secret by name.
- Never weaken security defaults (securityContext, runAsNonRoot, etc.) to make a
  test pass. Fix the test environment instead.
- Never add instructions of the form "edit a file inside the chart". Every
  configuration must be reachable via `-f values.yaml` or `--set`.
- `tests/golden/` files are read-only unless you explicitly run `make golden-update`
  and commit the diff with a justification.

## Requesting changes

Use the issue templates in `.github/ISSUE_TEMPLATE/` for bug reports and feature
requests. For security issues, contact the maintainer directly (see [SUPPORT.md](SUPPORT.md)).
