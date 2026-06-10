# Helm Chart Maturation Roadmap

Track against [CLAUDE.md](../CLAUDE.md) success criteria.  
Update this file in the same PR as the work. Read it at the start of each session.

---

## Phase 0 — Baseline & Safety Net

- [x] Inventory all chart variants; produce `docs/VARIANT-DIFF.md`
- [x] Snapshot rendered output into `tests/golden/<variant>/all.yaml` (5 variants captured)
- [x] Add `.github/workflows/lint.yml` running `helm lint` on every chart
- [x] Write `scripts/bootstrap.sh` with pinned tool versions
- [x] Create `Makefile` with `lint`, `template`, `golden`, `golden-update` targets
- [x] Create `.claude/settings.json` with permissions + hooks
- [x] Create `.claude/rules/helm-conventions.md` and `.claude/rules/testing.md`
- [x] Create `.claude/commands/` slash commands (verify, render, release-dry-run)
- [ ] **SECURITY:** Rotate hardcoded Docker PAT tokens in image-secret.yaml (lensb, nilsbuer) and replace with existingSecret pattern

---

## Phase 1 — Repo Hygiene

- [x] Fix README: remove placeholders, add helm show values / install workflow, correct GitHub URLs
- [x] Add `CONTRIBUTING.md`, issue templates, `CODEOWNERS`, `SUPPORT.md`
- [x] Add `ct.yaml` (chart-testing config) and `lintconf.yaml` (yamllint)
- [x] Fix version drift: `helm_uac_v1.5-aks` 1.4.1 → 1.5.0; `helm_ua_v1.5.1-ocp` 1.5.0 → 1.5.1; golden files regenerated

---

## Phase 2 — Chart Consolidation

- [x] Create `charts/universal-agent/` — single chart with `platform: aks|openshift|native`, `istio.enabled` independent flag
- [x] Create `charts/universal-controller/` — single chart, all 3 platforms; Deployment default + StatefulSet opt-in (`statefulSet.enabled`)
- [x] Declare `universal-agent` as optional subchart dependency (`agent.enabled`); resolved via `helm dep update` / `make dep-update`
- [x] Legacy chart directories kept; deprecation notice added to each `Chart.yaml`; golden snapshots generated for 5 platform modes
- [ ] Golden-file parity proof (Phase 5): consolidated charts must render identical output to legacy charts for equivalent values

---

## Phase 3 — Values API Design

- [x] Complete `image.repository / tag / pullPolicy / imagePullSecrets` pattern
- [x] `existingSecret` pattern for ALL credentials (DB, keystore, LDAP, OMS/TLS, Docker registry)
- [x] `database.{host,port,name,type,existingSecret}` (no bundled DB)
- [x] `extraEnv`, `extraVolumes`, `extraVolumeMounts`, `extraObjects` escape hatches
- [x] `podAnnotations`, `commonLabels`, `nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`
- [x] `values.schema.json` for both charts (required fields, enums, types)
- [x] Run `helm-docs` to generate values tables in README

---

## Phase 4 — Production Hardening Defaults

- [x] `securityContext`: runAsNonRoot, seccompProfile RuntimeDefault, drop ALL caps — fully overridable via `securityContext.*` values (OCP restricted-v2 compatible with user override)
- [x] Probes: startupProbe with generous failureThreshold (310s window for Tomcat), separate liveness/readiness; all thresholds exposed as `ucProbes.*` / `omsProbes.*` / `{startup,liveness,readiness}Probe.*` values
- [x] Resources: defaults sized for small prod footprint; JVM heap via `jvm.maxRamPercentage` → `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=<n>` on UC
- [x] HA: PodDisruptionBudget (minAvailable:1) + soft podAntiAffinity rendered when `replicaCount >= 2` and `ha.podAntiAffinity.enabled=true`
- [x] Optional `networkPolicy.enabled` (both charts), `serviceMonitor.enabled` (UC, CRD-guarded)

---

## Phase 5 — Testing & CI

- [x] `helm unittest` suites: 101 tests across 8 suites (UA: deployment, ha, platforms; UC: deployment, credentials/existingSecret, database, ha, platforms)
- [x] `kubeconform -strict` + `kube-score` on `helm template` output (all platform modes, in CI)
- [x] Golden-file diff in CI covering all 13 render modes (5 legacy + 3 UA + 5 UC); `make golden-update` procedure documented
- [x] `ct lint` in CI via chart-testing-action; `tests/values/{native,openshift,aks}-smoke.yaml` overlays created for Phase 5b
- [x] `ct install` against kind cluster (matrix: k8s 1.29, 1.30) — `.github/workflows/ci-install.yaml` with `--wait=false` (validates API acceptance, not application start)
- [ ] Live smoke tests on all three platforms (Phase 5b — requires maintainer cluster access)

### Phase 5b — Live Test Deployments (Three Platforms)

- [x] `scripts/smoke-test.sh <platform>` — namespace isolation, trap cleanup, rollout wait, helm test, platform assertions, artifact collection
- [x] `tests/values/{native,openshift,aks}-smoke.yaml` — overlay files for each platform
- [x] `make smoke PLATFORM=<native|openshift|aks>` and `make smoke-all`
- [x] `charts/*/templates/tests/test-*.yaml` — helm test hooks (UC: HTTP health + OMS port; UA: UDM port); gated by `test.enabled` (set `false` in ci/ values)
- [x] `charts/*/ci/ct-values.yaml` — kind-compatible values (busybox image, `test.enabled: false`, `--wait=false`)
- [x] `ct.yaml` updated: `chart-dirs: [charts]`, `--wait=false`
- [ ] Fill `EXPECTED_CONTEXTS` map in `smoke-test.sh` with real context names (requires cluster access)
- [ ] Obtain cluster access from maintainer (namespace-scoped, not cluster-admin)

---

## Phase 6 — Publishing & Supply Chain

- [x] `helm/chart-releaser-action` → GitHub Pages index on tag (`release.yaml`)
- [x] `helm push` OCI artifacts to `ghcr.io/stonebranchpm/charts/<name>`
- [x] Cosign keyless signing of OCI artifacts (`cosign sign --yes`, OIDC, no stored key); verification instructions appended to each GitHub Release
- [x] Tag scheme: `universal-controller-X.Y.Z` / `universal-agent-X.Y.Z`; `cr.yaml` wires chart-releaser to `charts/` dir
- [x] `charts/*/CHANGELOG.md` per chart; `docs/COMPATIBILITY.md` with DB + OCP + k8s version matrix
- [x] `release-charts.yml` demoted to `workflow_dispatch`-only with migration banner in release body

### One-time bootstrap (manual, before first release)

1. **Create `gh-pages` branch** (empty orphan):
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   git commit --allow-empty -m "init gh-pages"
   git push origin gh-pages
   git checkout main
   ```
2. **Enable GitHub Pages** in repo Settings → Pages → Source: `gh-pages` branch, root `/`
3. **First release**: push a tag → `git tag universal-agent-1.5.1 && git push origin universal-agent-1.5.1`
4. **Verify** index at `https://stonebranchpm.github.io/helm-charts/index.yaml`

---

## Current Session Log

| Date | Phase | Work Done |
|---|---|---|
| 2026-06-10 | 0 | Initial Phase 0 execution: VARIANT-DIFF.md, golden snapshots (5 variants), lint.yml, bootstrap.sh, Makefile, ROADMAP.md, project settings |
| 2026-06-10 | 1 | README rewritten (no placeholders, helm show values workflow), CONTRIBUTING.md, SUPPORT.md, CODEOWNERS, issue templates, ct.yaml, lintconf.yaml, version drift fixed (uc-aks 1.5.0, ua-ocp 1.5.1), golden files regenerated |
| 2026-06-10 | 2 | charts/universal-agent and charts/universal-controller created; platform detection helpers; StatefulSet opt-in; subchart dependency wired; golden snapshots for 5 platform modes; lint.yml updated; legacy charts deprecated |
| 2026-06-10 | 3 | Values API redesigned: image.*/imagePullSecrets; persistence.*; database.*; credentials.existingSecret; pod topology (podAnnotations/tolerations/affinity/topologySpreadConstraints); escape hatches (extraEnv/extraVolumes/extraVolumeMounts/extraObjects); values.schema.json for both charts; helm-docs README generated; image-secret.yaml removed in favour of imagePullSecrets list |
| 2026-06-10 | 4 | securityContext fully overridable (OCP restricted-v2 compatible); startupProbe added to UA+OMS; all probe thresholds values-driven; JVM MaxRAMPercentage on UC; PDB+podAntiAffinity when replicaCount>=2; networkPolicy.enabled on both charts; serviceMonitor.enabled on UC (CRD-guarded); extraObjects template added to both charts |
| 2026-06-10 | 5 | helm-unittest: 101 tests, 8 suites covering defaults/security/platforms/HA/existingSecret/database/persistence; CI rewritten with 5 jobs (lint, unittest, kubeconform+kube-score, golden-diff, ct-lint); Makefile golden+template+unittest targets extended to new charts; tests/values/{native,openshift,aks}-smoke.yaml created for Phase 5b |
| 2026-06-10 | 5b | scripts/smoke-test.sh (namespace isolation, trap cleanup, rollout wait, helm test, platform assertions, artifact collection); helm test hooks for UC (HTTP health + OMS port) and UA (UDM port) with test.enabled guard; ci/ct-values.yaml for kind-based ct install; .github/workflows/ci-install.yaml (kind matrix k8s 1.29/1.30); ct.yaml updated to charts/ dir + --wait=false |
| 2026-06-10 | 6 | release.yaml: chart-releaser (gh-pages index) + OCI push to ghcr.io + Cosign keyless sign + verification instructions in release notes; cr.yaml; CHANGELOG per chart; COMPATIBILITY.md; release-charts.yml demoted to workflow_dispatch-only with migration banner |
