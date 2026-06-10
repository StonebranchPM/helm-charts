# Changelog — universal-agent

All notable changes to this chart are documented here.
Versions follow [Semantic Versioning](https://semver.org/).
Chart version is independent of the UAC `appVersion`; see the
[compatibility matrix](../../docs/COMPATIBILITY.md) for the supported pairings.

---

## [1.5.1] — 2026-06-10

### Added
- Single consolidated chart replaces four per-platform forks (`helm_ua_v1.5.1-aks`, `helm_ua_v1.5.1-ocp`, etc.)
- `platform: aks|openshift|native` value selects Route/Ingress/VirtualService rendering
- `istio.enabled` as an independent feature flag (no longer coupled to `platform: aks`)
- `imagePullSecrets: []` list — pre-existing secrets, no chart-managed docker pull secret
- `persistence.{enabled,storageClassName,size,accessMode,existingClaim}` pattern
- `securityContext.{pod,container}` fully overridable; defaults pass OpenShift restricted-v2 SCC
- `startupProbe` with generous `failureThreshold` for OMS startup; all probe thresholds as values
- `ha.podAntiAffinity.enabled` — soft anti-affinity rendered when `replicaCount >= 2`
- `PodDisruptionBudget` rendered when `replicaCount >= 2`
- `networkPolicy.enabled` with configurable additional ingress/egress rules
- `extraEnv`, `extraVolumes`, `extraVolumeMounts`, `extraObjects` escape hatches
- `podAnnotations`, `commonLabels`, `nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`
- `values.schema.json` with required fields, enums, type enforcement
- `helm test` hook (`test-connection.yaml`) verifying UDM port 7887; gated by `test.enabled`

### Changed
- `uaDeployment.image.*` → `image.*`
- `uaDeployment.replicas` → `replicaCount`
- `TLSProtocol` → `istio.tlsProtocol`
- Persistence keys consolidated under `persistence.*`

### Deprecated
- Legacy per-platform chart directories (`helm_ua_v1.5.1-aks/`, `helm_ua_v1.5.1-ocp/`) — use this chart with `platform` value instead

---

## [1.5.0] — legacy (pre-consolidation)

Baseline captured from `helm_ua_v1.5.1-aks` / `helm_ua_v1.5.1-ocp` ZIP release.
