# Chart Variant Diff — Phase 0 Inventory

Generated: 2026-06-10  
Baseline helm version: 3.18.1

---

## Chart Overview

| Directory | Component | Platform | Chart Version | appVersion |
|---|---|---|---|---|
| `helm_ua_v1.5.1-aks` | Universal Agent | AKS + Istio | 1.5.1 | 7.9.0.0 |
| `helm_ua_v1.5.1-ocp` | Universal Agent | OpenShift | 1.5.0 | 7.9.0.0 |
| `helm_uac_v1.0-native` | UC + OMS | Native K8s | 1.4.1 | 7.9.0.0 |
| `helm_uac_v1.4.1-ocp` | UC + OMS | OpenShift | 1.4.1 | 7.9.0.0 |
| `helm_uac_v1.5-aks` | UC + OMS | AKS + Istio | 1.4.1 | 7.9.0.0 |

> Note: `helm_uac_v1.5-aks` has directory name `v1.5` but Chart.yaml says `version: 1.4.1` — version drift issue tracked in Phase 1.

---

## Universal Agent (UA) Variants

### Template File Comparison

| Template | AKS | OCP | Notes |
|---|---|---|---|
| `_helpers.tpl` | ✓ | ✓ | Shared helpers; `uac.emitIfSet` defined in both |
| `configmap.yaml` | ✓ | ✓ | Differs (see below) |
| `deployment.yaml` | ✓ | ✓ | Differs (see below) |
| `pvc.yaml` | ✓ | ✓ | Structurally identical |
| `service.yaml` | ✓ | ✓ | Differs: AKS=oms+udm ports, OCP=udm only + conditional oms service |
| `configmap-sni.yaml` | — | ✓ | OCP only: SNI configmap populated post-install via Route hostname |
| `gateway.yaml` | ✓ | — | AKS only: Istio Gateway (443 HTTPS, 444 OMS passthrough, 445 UDM passthrough) |
| `hostname-appendum.yaml` | — | ✓ | OCP only: post-install Job + SA + Role + RoleBinding to patch SNI configmap from Route hostname |
| `route.yaml` | — | ✓ | OCP only: OpenShift Route for UDM/OMS TLS |
| `serviceaccount.yaml` | ✓ | — | AKS only: WorkloadIdentity-annotated ServiceAccount |
| `virtualservice.yaml` | ✓ | — | AKS only: Istio VirtualService (UDM + OMS TCP routing) |

### Key Behavioural Differences

**UAGTLSSNIHOSTNAME env var:**
- AKS: Hardcoded in configmap as `"{{ .Values.istio.udmConnectionPort }}@{{ .Values.istio.host }}:{{ .Values.istio.host }}"` — not overridable without editing the template
- OCP: Populated dynamically from Route hostname via post-install `hostname-appendum` Job; fallback to `uaConfig.uagtlssnihostname` value

**Identity / ServiceAccount:**
- AKS: Creates a dedicated ServiceAccount with `azure.workload.identity/client-id` annotation; pod uses this SA
- OCP: No ServiceAccount created; uses default SA

**Ingress / Routing:**
- AKS: Istio Gateway + VirtualService (requires Istio control plane)
- OCP: OpenShift Route + optional SNI configmap

**OMS Service:**
- AKS: Always renders oms (port 7878) + udm (port 7887) in the same Service object
- OCP: Only renders udm (port 7887); oms Service conditionally rendered when `uaConfig.omsAutoStart == "yes"`

**PVC volumeMount:**
- AKS: PVC mount at `/var/opt/universal/spool/oms` always present when `uaDeployment.pvc.enabled`
- OCP: Same, but wrapped in explicit `{{- if .Values.uaDeployment.pvc.enabled }}` blocks on both volumeMounts and volumes

### Values Structural Differences (UA)

| Value | AKS | OCP |
|---|---|---|
| `workloadIdentity.enabled` | ✓ (default: true) | — |
| `workloadIdentity.clientId` | ✓ | — |
| `workloadIdentity.serviceAccountName` | ✓ | — |
| `istio.enabled` | ✓ (default: true) | — |
| `istio.host` | ✓ | — |
| `istio.hostCredentials` | ✓ | — |
| `istio.TLSProtocol` | ✓ | — |
| `istio.udmConnectionPort` | ✓ | — |
| `istio.udmConnectionPortInternal` | ✓ | — |
| `tlssnihostnameref.enabled` | — | ✓ (OCP Route lookup) |
| `uaConfig.uagtlssnihostname` | — | ✓ (manual override) |
| `uaConfig.omsAutoStart` | same key | same key, but gates OMS service rendering in OCP |

---

## Universal Controller + OMS (UAC) Variants

### Template File Comparison

| Template | native | OCP | AKS | Notes |
|---|---|---|---|---|
| `_helpers.tpl` | ✓ | ✓ | ✓ | Similar; native has OMS/UC namespace overrides; OCP/AKS do not |
| `image-secret.yaml` | ✓ | ✓ | ✓ | **[SECURITY]** Hardcoded base64 Docker PAT tokens (see below) |
| `oms-configmap.yaml` | ✓ | ✓ | ✓ | OCP uses `omsConfig.*` keys; AKS uses `omsConfig.*` (renamed from OCP); native uses same |
| `oms-pvc.yaml` | — | ✓ | ✓ | Not in native (OMS uses StatefulSet VolumeClaimTemplate) |
| `rbac.yaml` | ✓ | — | ✓ | native + AKS only; OCP relies on built-in SCC |
| `service.yaml` | ✓ | ✓ | ✓ | Differs (see below) |
| `uc-configmap.yaml` | ✓ | ✓ | ✓ | Structurally similar; AKS adds KeyVault env var injection |
| `uc-secret.yaml` | ✓ | ✓ | ✓ | Holds DB password + truststore password |
| `gateway.yaml` | — | — | ✓ | AKS only: Istio Gateway (80 HTTP, 443 HTTPS, 444 OMS passthrough, 445 UDM passthrough) |
| `hostname-appendum.yaml` | — | ✓ | — | OCP only: post-install Job to patch OMS configmap with Route hostname |
| `ingress.yaml` | ✓ | — | — | native only: standard K8s Ingress |
| `keyvault.yaml` | — | — | ✓ | AKS only: SecretProviderClass for Azure Key Vault CSI driver |
| `oms-deployment.yaml` | — | ✓ | ✓ | OCP + AKS use Deployment |
| `oms-statefulset.yaml` | ✓ | — | — | native only: StatefulSet (with headless service + VolumeClaimTemplate) |
| `route.yaml` | — | ✓ | — | OCP only: OpenShift Route (TLS passthrough) |
| `uc-deployment.yaml` | — | ✓ | ✓ | OCP + AKS use Deployment |
| `uc-statefulset.yaml` | ✓ | — | — | native only: StatefulSet (with headless service + VolumeClaimTemplate) |
| `virtualservice-oms.yaml` | — | — | ✓ | AKS only: Istio VirtualService for OMS TCP |
| `virtualservice-uc.yaml` | — | — | ✓ | AKS only: Istio VirtualService for UC HTTP→HTTPS + HTTPS passthrough |

### Workload Type Divergence

| Chart | UC workload | OMS workload | Implication |
|---|---|---|---|
| native | StatefulSet | StatefulSet | Stable pod identity, stable storage via VolumeClaimTemplates; requires headless Service |
| OCP | Deployment | Deployment | Storage via standalone PVC; no stable pod identity |
| AKS | Deployment | Deployment | Same as OCP; adds KeyVault CSI init volumes |

This is the highest-risk consolidation point: StatefulSet ↔ Deployment is a breaking change that cannot be done in-place. Phase 2 consolidation must default to Deployment + standalone PVC for portability, with StatefulSet as opt-in.

### Ingress / Routing Comparison

| Chart | Method | Notes |
|---|---|---|
| native | K8s Ingress | `ingress.enabled` guard; `ingress.className`, `ingress.host`, `ingress.tls` values |
| OCP | OpenShift Route | `route.yaml` with TLS passthrough; hostname-appendum Job patches OMS configmap |
| AKS | Istio Gateway + VirtualService | `istio.enabled` guard; 2 VirtualServices (oms + uc); Gateway on 80/443/444/445 |

### OMS ConfigMap Key Name Discrepancy

| Feature | OCP (`omsConfig.*`) | AKS (`omsConfig.*`) | native (`omsConfig.*`) |
|---|---|---|---|
| Key prefix | `omsConfig` | `omsConfig` | `omsConfig` |
| Config key naming | `uagagentclusters`, `businessservices`, … | Same keys | Same keys |
| OCP-only key | — | — | — |

OCP and AKS share the same `omsConfig.*` key names in values.yaml — the configmap template body differs only in how `UAGTLSSNIHOSTNAME` is populated.

### Values Structural Differences (UAC)

| Value | native | OCP | AKS |
|---|---|---|---|
| `oms.namespace` | ✓ (per-component NS override) | — | — |
| `ucDeployment.namespace` | ✓ (per-component NS override) | — | — |
| `route.enabled` | — | ✓ | — |
| `istio.enabled` | — | — | ✓ |
| `istio.host` | — | — | ✓ |
| `istio.hostCredentials` | — | — | ✓ |
| `istio.omsConnectionPort` | — | — | ✓ (default 444) |
| `istio.udmConnectionPort` | — | — | ✓ (default 445) |
| `keyVault.enabled` | — | — | ✓ |
| `keyVault.managedIdentityClientId` | — | — | ✓ |
| `keyVault.secrets[]` | — | — | ✓ |
| `serviceAccount.name` | — | — | ✓ |
| `nodeSelector` | — | — | ✓ |
| `istiosidecar.enabled` | — | — | ✓ |
| `tlssnihostnameref.enabled` | — | ✓ | — |
| `ingress.*` | ✓ | — | — |

---

## Security Issues Found

### CRITICAL: Hardcoded Docker Registry PAT Tokens

Three `image-secret.yaml` templates contain base64-encoded Docker Hub PAT tokens committed to the repo. These tokens are trivially decoded with `base64 -d`.

| Chart | Username | Token fragment |
|---|---|---|
| `helm_uac_v1.0-native` | `lensb` | `[REDACTED]` |
| `helm_uac_v1.4.1-ocp` | `nilsbuer` | `[REDACTED]` |
| `helm_uac_v1.5-aks` | `nilsbuer` | `[REDACTED]` (same token) |

**Required action before Phase 2:** Rotate both PATs immediately. Replace hardcoded base64 with the `existingSecret` pattern — accept a pre-created `kubernetes.io/dockerconfigjson` secret name as `ucDeployment.imagePullSecrets.secretName`. Never embed credentials in chart templates.

---

## helm lint Results

All 5 charts pass `helm lint` with only INFO-level notices (missing icon URL).  
No errors or warnings. Lint baseline is clean.

---

## Golden File Snapshots

Baseline rendered output captured in `tests/golden/<variant>/all.yaml` using:

```sh
helm template test-release <chart-dir> > tests/golden/<variant>/all.yaml
```

Line counts: ua-aks=376, ua-ocp=373, uac-native=414, uac-ocp=734, uac-aks=448.

These snapshots are the regression baseline. Any refactor must diff against them and explain all changes.

---

## Consolidation Guidance for Phase 2

Based on this analysis, the recommended consolidation approach:

1. **`charts/universal-agent/`** — One chart. `platform: aks | openshift | native` value selects:
   - `aks`: Render Gateway, VirtualService, ServiceAccount (WorkloadIdentity)
   - `openshift`: Render Route, hostname-appendum hook, SNI configmap
   - `native` (new): No cloud-specific routing; bare Service only
   - `istio.enabled` is a separate flag (decoupled from platform, since OCP can also have Istio)

2. **`charts/universal-controller/`** — One chart. `platform` drives:
   - `native`: StatefulSets + Ingress + RBAC
   - `openshift`: Deployments + Route + hostname-appendum
   - `aks`: Deployments + Istio Gateway/VirtualServices + KeyVault + RBAC + nodeSelector
   - `oms.enabled` subcomponent flag (currently `oms.enabled: true` in all)

3. **Image pull secret:** Replace hardcoded base64 with `imagePullSecrets: []` accepting pre-created secret names across all charts.
