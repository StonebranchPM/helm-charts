# Stonebranch Universal Automation Helm Charts

This repository contains production-ready Helm charts for deploying Stonebranch Universal Automation components on Kubernetes platforms.

## Downloads

Pre-packaged Helm charts are available as ZIP files in the [**GitHub Releases**](../../releases/latest) section.

### Available Charts

#### Universal Agent Charts (Ready to Use)
- **helm_ua_v1.4.2.zip** - Universal Agent v1.4.2 (generic Kubernetes deployment)
- **helm_ua_v1.5-AKS.zip** - Universal Agent v1.5 for Azure Kubernetes Service (with Istio support)
- **helm_ua_v1.5-OCP.zip** - Universal Agent v1.5 for OpenShift Container Platform

#### Universal Controller + Agent Charts (Requires Configuration)
- **helm_uac_v1.4-AKS.zip** - Universal Controller + Agent v1.4 for Azure Kubernetes Service
- **helm_uac_v1.4-OCP.zip** - Universal Controller + Agent v1.4 for OpenShift Container Platform

> **⚠️ Important:** UAC (Universal Controller) charts require you to provide your own Universal Controller image details in `values.yaml` before deployment:
> - Set `ucDeployment.image.repository` to your controller image repository
> - Set `ucDeployment.image.tag` to your desired version tag

## Installation

### 1. Download and Extract

```bash
# Download the appropriate chart for your platform from Releases
wget https://github.com/YOUR_ORG/YOUR_REPO/releases/download/latest/helm_ua_v1.5-AKS.zip

# Extract the chart
unzip helm_ua_v1.5-AKS.zip
cd helm_ua_v1.5-AKS
```

### 2. Review and Customize values.yaml

Edit `values.yaml` according to your environment:

```bash
vi values.yaml
```

Key configuration areas:
- **Image settings** (UAC charts only - provide your controller image)
- **Resource requests/limits**
- **Persistent volume settings**
- **Networking** (Istio for AKS, Routes for OpenShift)
- **Database connection** (for UAC charts)
- **LDAP/SAML configuration** (optional)

### 3. Install the Chart

```bash
# Install with Helm 3
helm install my-universal-agent . -n stonebranch --create-namespace

# Or specify custom values
helm install my-universal-agent . -n stonebranch \
  --set image.tag=7.9.0.0 \
  --set resources.requests.memory=2Gi
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -n stonebranch

# Check logs
kubectl logs -n stonebranch -l app=universal-agent

# For OpenShift, check routes
oc get routes -n stonebranch
```

## Chart Details

### Platform Support

| Chart | Platform | Service Mesh | Version |
|-------|----------|--------------|---------|
| helm_ua_v1.4.2 | Generic Kubernetes | None | v1.4.2 |
| helm_ua_v1.5-AKS | Azure Kubernetes Service | Istio | v1.5 |
| helm_ua_v1.5-OCP | OpenShift Container Platform | Routes | v1.5 |
| helm_uac_v1.4-AKS | Azure Kubernetes Service | Istio | v1.4 |
| helm_uac_v1.4-OCP | OpenShift Container Platform | Routes | v1.4 |

### Features

- **Production-ready configurations** with resource limits and health checks
- **Persistent volume support** for agent data and logs
- **External database integration** (UAC charts)
- **Service mesh integration** (Istio for AKS, Routes for OpenShift)
- **Azure Key Vault integration** (AKS charts - optional)
- **OpenTelemetry support** for observability
- **Configurable LDAP/SAML authentication** (UAC charts)

## Security Notes

- The `image-secret.yaml` file is excluded from this repository (`.gitignore`)
- If using private registries, create your own image pull secrets:

```bash
kubectl create secret docker-registry my-registry-secret \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n stonebranch
```

Then reference it in `values.yaml`:
```yaml
imagePullSecrets:
  enabled: true
# Create templates/image-secret.yaml with your secret configuration
```

## Upgrading

```bash
# Update values if needed
vi values.yaml

# Upgrade the release
helm upgrade my-universal-agent . -n stonebranch

# Rollback if needed
helm rollback my-universal-agent -n stonebranch
```

## Uninstalling

```bash
helm uninstall my-universal-agent -n stonebranch
```

## Support

For questions, issues, or feature requests:

- **Maintainer:** len-maurice.seemann@stonebranch.com
- **Team:** Product & Solutions Management Team
- **Application Version:** 7.9.0.0

## Development

### Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── release-charts.yml    # Automated release workflow
├── helm_ua_v1.4.2/               # Universal Agent v1.4.2
├── helm_ua_v1.5-AKS/             # Universal Agent v1.5 (AKS)
├── helm_ua_v1.5-OCP/             # Universal Agent v1.5 (OpenShift)
├── helm_uac_v1.4-AKS/            # Universal Controller + Agent (AKS)
├── helm_uac_v1.4-OCP/            # Universal Controller + Agent (OpenShift)
└── README.md
```

### Automated Releases

Charts are automatically packaged and published on every push to `main`. The workflow:
1. Copies all chart directories
2. Sanitizes UAC charts (removes private image references)
3. Creates ZIP files
4. Publishes to GitHub Releases under the `latest` tag

---

**© 2024 Stonebranch - Universal Automation Center**
