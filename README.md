# Stonebranch Universal Automation Helm Charts

Production-ready Helm charts for deploying Stonebranch Universal Automation components on Kubernetes and OpenShift. A single chart per component covers all platforms — no forking required.

> For questions or support see [SUPPORT.md](SUPPORT.md). To contribute see [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Charts

| Chart | Description | Platforms |
|---|---|---|
| `universal-agent` | Universal Agent (OMS + UAG + UDM) | AKS, OpenShift, native Kubernetes |
| `universal-controller` | Universal Controller + OMS Agent | AKS, OpenShift, native Kubernetes |

Platform differences (Route vs Ingress vs VirtualService, Istio sidecar, OCP SCC) are controlled via `platform: aks|openshift|native` and `istio.enabled` — no separate chart per platform.

---

## Installing from the Helm repository

The recommended install method. The index is served from GitHub Pages and charts are fetched automatically.

```bash
helm repo add stonebranch https://stonebranchpm.github.io/helm-charts
helm repo update
```

### Universal Agent

```bash
# Review all available values first
helm show values stonebranch/universal-agent > my-ua-values.yaml

# Install (example: AKS with Istio)
helm install my-ua stonebranch/universal-agent \
  --version 1.5.1 \
  --namespace stonebranch --create-namespace \
  -f my-ua-values.yaml
```

### Universal Controller

The UC chart requires a customer-supplied controller image and an external database — no image or database is bundled.

```bash
# Review all available values first
helm show values stonebranch/universal-controller > my-uc-values.yaml

# Install (example: native Kubernetes)
helm install my-uc stonebranch/universal-controller \
  --version 1.5.0 \
  --namespace stonebranch --create-namespace \
  -f my-uc-values.yaml
```

Minimum required values for UC:

```yaml
platform: native   # aks | openshift | native

uc:
  image:
    repository: <your-registry>/universal-controller
    tag: "7.9.0.0"

database:
  host: db.example.com
  port: 5432
  name: uc_db
  type: postgresql
  user: ucadmin
  existingSecret: uc-db-secret   # key: password

credentials:
  existingSecret: uc-passwords   # keys: password, password-keystore,
                                 #       password-truststore,
                                 #       UC_TRUSTMANAGER_TRUSTSTORE_PASSWORD_ENCRYPTED
```

---

## Installing from a downloaded package

Download the `.tgz` from the [Releases](../../releases) page, then:

```bash
# Inspect default values
helm show values universal-controller-1.5.0.tgz > my-values.yaml

# Edit my-values.yaml, then install
helm install my-uc universal-controller-1.5.0.tgz \
  --namespace stonebranch --create-namespace \
  -f my-values.yaml
```

---

## Upgrading

```bash
helm repo update
helm upgrade my-uc stonebranch/universal-controller \
  --version 1.5.1 \
  -f my-values.yaml

# Rollback if needed
helm rollback my-uc -n stonebranch
```

---

## Uninstalling

```bash
helm uninstall my-uc -n stonebranch
```

---

## Configuration highlights

All configuration is done through values — nothing inside the chart needs to be edited.

| Area | Key values |
|---|---|
| Platform | `platform: aks\|openshift\|native` |
| Istio | `istio.enabled`, `istio.host` |
| Image pull secrets | `imagePullSecrets: [{name: my-pull-secret}]` |
| DB credentials | `database.*`, `credentials.existingSecret` |
| Security context | `securityContext.{uc,oms}.{pod,container}` — fully overridable, OCP restricted-v2 compatible |
| Probes | `ucProbes.*`, `omsProbes.*` — all thresholds exposed as values |
| JVM heap | `jvm.maxRamPercentage: 75` |
| HA | `uc.replicaCount: 2` enables PDB + soft pod anti-affinity |
| NetworkPolicy | `networkPolicy.enabled: true` |
| Prometheus | `serviceMonitor.enabled: true` (UC only, requires Prometheus Operator CRD) |
| Escape hatches | `extraEnv`, `extraVolumes`, `extraVolumeMounts`, `extraObjects` |

Full values reference: `helm show values stonebranch/<chart>`

---

## Repository structure

```
charts/
├── universal-agent/        # Consolidated UA chart (replaces helm_ua_* variants)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── CHANGELOG.md
│   └── templates/
└── universal-controller/   # Consolidated UC chart (replaces helm_uac_* variants)
    ├── Chart.yaml
    ├── values.yaml
    ├── CHANGELOG.md
    └── templates/

helm_ua_v1.5.1-aks/        # Legacy — use charts/universal-agent instead
helm_ua_v1.5.1-ocp/        # Legacy — use charts/universal-agent instead
helm_uac_v1.0-native/      # Legacy — use charts/universal-controller instead
helm_uac_v1.4.1-ocp/       # Legacy — use charts/universal-controller instead
helm_uac_v1.5-aks/         # Legacy — use charts/universal-controller instead

docs/
├── ROADMAP.md
├── COMPATIBILITY.md        # Supported UAC versions, Kubernetes versions, databases
└── VARIANT-DIFF.md         # Platform diff captured at consolidation baseline
```

---

**© Stonebranch — Universal Automation Center**
