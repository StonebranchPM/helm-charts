# Changelog — universal-controller

All notable changes to this chart are documented here.
Versions follow [Semantic Versioning](https://semver.org/).
Chart version is independent of the UAC `appVersion`; see the
[compatibility matrix](../../docs/COMPATIBILITY.md) for the supported pairings.

---

## [1.5.0] — 2026-06-10

### Added
- Single consolidated chart replaces three per-platform forks (`helm_uac_v1.0-native`, `helm_uac_v1.4.1-ocp`, `helm_uac_v1.5-aks`)
- `platform: aks|openshift|native` value selects Route/Ingress/VirtualService rendering
- `istio.enabled` as an independent feature flag
- `imagePullSecrets: []` list replaces the old `ucDeployment.imagePullSecrets.enabled` + bundled docker secret
- `database.{host,port,name,type,user,existingSecret}` structured block with JDBC URL auto-computation
- `credentials.existingSecret` pattern — suppresses `uc-secret.yaml` rendering entirely when set
- `credentials.{passwordKey,keystorePasswordKey,truststorePasswordKey,truststoreEncryptedKey}` configurable secret key names
- `uc.*` / `oms.*` namespaced image + resource values (was `ucDeployment.*` / `omsDeployment.*`)
- `securityContext.{uc,oms}.{pod,container}` fully overridable; defaults pass OpenShift restricted-v2 SCC
- `startupProbe` added to OMS container with 310-second window; all probe thresholds values-driven via `ucProbes.*` / `omsProbes.*`
- `jvm.maxRamPercentage` → `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=<n>` on UC container
- `ha.podAntiAffinity.enabled` + `PodDisruptionBudget` when `uc.replicaCount >= 2`
- `networkPolicy.enabled`, `serviceMonitor.enabled` (CRD-guarded)
- `extraEnv`, `extraVolumes`, `extraVolumeMounts`, `extraObjects` escape hatches
- `podAnnotations`, `commonLabels`, `nodeSelector`, `tolerations`, `affinity`, `topologySpreadConstraints`
- `values.schema.json` with required fields, enums, type enforcement
- `helm test` hook (`test-health.yaml`) verifying UC HTTP health + OMS port 7878; gated by `test.enabled`
- `universal-agent` declared as optional subchart dependency (`agent.enabled: false`)

### Changed
- `ucDeployment.image.*` → `uc.image.*`
- `omsDeployment.image.*` → `oms.image.*`
- `ucDeployment.replicas` → `uc.replicaCount`
- `omsDeployment.replicas` → `oms.replicaCount`
- `oms.existingClaim` → `oms.persistence.existingClaim`
- `istio.TLSProtocol` → `istio.tlsProtocol`
- `image-secret.yaml` template removed — use `imagePullSecrets` list referencing pre-existing secrets

### Deprecated
- Legacy per-platform chart directories (`helm_uac_v1.0-native/`, `helm_uac_v1.4.1-ocp/`, `helm_uac_v1.5-aks/`)
- `ucConfig.ucDbUrl/ucDbName/ucDbUser/ucDbRdbms` — use `database.*` block instead (kept as fallback)

---

## [1.4.1] — legacy (pre-consolidation)

Baseline captured from `helm_uac_v1.5-aks` ZIP release.
