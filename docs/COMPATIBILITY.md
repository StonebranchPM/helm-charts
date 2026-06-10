# Compatibility Matrix

Chart versions that have been validated against each UAC application version.

| Chart | Chart Version | UAC appVersion | Kubernetes | Notes |
|---|---|---|---|---|
| universal-agent | 1.5.1 | 7.9.0.0 | 1.27–1.30 | AKS, OpenShift 4.x, native k8s; Istio 1.20+ |
| universal-controller | 1.5.0 | 7.9.0.0 | 1.27–1.30 | Requires external DB (MySQL 8+ or PostgreSQL 14+) |

## Upgrade notes

- **universal-controller 1.4.x → 1.5.0**: Values API redesigned. Map old keys to new ones using the
  [CHANGELOG](../charts/universal-controller/CHANGELOG.md). Run `helm diff upgrade` before applying.
- **universal-agent 1.x legacy forks → 1.5.1**: Replace per-platform chart install with a single
  `helm install --set platform=<aks|openshift|native>` invocation.

## Database compatibility

| Database | Minimum version | JDBC type string |
|---|---|---|
| PostgreSQL | 14 | `postgresql` |
| MySQL | 8.0 | `mysql` |
| Oracle | 19c | `oracle:thin` |
| MSSQL | 2019 | `sqlserver` |

## OpenShift

Charts have been validated against OpenShift 4.12+ with the `restricted-v2` SCC.
Do **not** set `securityContext.uc.pod.runAsUser` / `runAsGroup` on OpenShift — the SCC
assigns UID from the namespace range automatically. See the smoke values overlay
`tests/values/openshift-smoke.yaml` for a reference configuration.
