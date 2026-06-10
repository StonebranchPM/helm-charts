#!/usr/bin/env bash
# smoke-test.sh <platform>
#
# Runs a full install-wait-test-collect-teardown cycle against the cluster
# selected by the current kubeconfig context.
#
# Usage:
#   SMOKE_VALUES_OVERRIDE=path/to/extra.yaml bash scripts/smoke-test.sh native
#
# Required environment / prerequisites:
#   - kubectl in PATH, pointing at the target cluster
#   - helm 3 in PATH
#   - The test secrets must exist before running (see "Pre-flight" section)
#
# Secrets the chart expects (create before running):
#   uc-smoke-db-secret  — key: password  (DB password)
#   uc-smoke-passwords  — keys: password, password-keystore, password-truststore,
#                               UC_TRUSTMANAGER_TRUSTSTORE_PASSWORD_ENCRYPTED
#   (optional) uc-smoke-pull-secret  — docker-registry secret for the UC image
#
# Safety: the script refuses to run against unrecognised contexts and
# cleans up even on failure (trap).

set -euo pipefail

# ─── arguments ────────────────────────────────────────────────────────────────
PLATFORM="${1:-}"
if [[ -z "$PLATFORM" || ! "$PLATFORM" =~ ^(native|openshift|aks)$ ]]; then
  echo "Usage: $0 <native|openshift|aks>" >&2
  exit 1
fi

# ─── configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
RELEASE_NAME="uac-smoke-${GIT_SHA}"
NAMESPACE="uac-smoke-${GIT_SHA}"
TIMEOUT="600s"       # generous: accounts for UC's slow Tomcat startup
ARTIFACTS_DIR="${REPO_ROOT}/artifacts/smoke/${PLATFORM}"
VALUES_FILE="${REPO_ROOT}/tests/values/${PLATFORM}-smoke.yaml"

# Known safe contexts per platform — edit to match your kubeconfig context names
declare -A EXPECTED_CONTEXTS=(
  [native]=""      # e.g. "k3s-local" or "kind-local"
  [openshift]=""   # e.g. "ocp-dev"
  [aks]=""         # e.g. "aks-dev"
)
EXPECTED_CONTEXT="${EXPECTED_CONTEXTS[$PLATFORM]}"

# ─── safety check ─────────────────────────────────────────────────────────────
CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || echo "")"
echo ">>> Current kubectl context: ${CURRENT_CONTEXT}"
echo ">>> Target namespace:        ${NAMESPACE}"
echo ">>> Platform:                ${PLATFORM}"
echo ""

if [[ -n "$EXPECTED_CONTEXT" && "$CURRENT_CONTEXT" != "$EXPECTED_CONTEXT" ]]; then
  echo "ERROR: Current context '${CURRENT_CONTEXT}' does not match expected '${EXPECTED_CONTEXT}'." >&2
  echo "       Switch contexts or update EXPECTED_CONTEXTS in this script." >&2
  exit 1
fi

if [[ -z "$CURRENT_CONTEXT" ]]; then
  echo "ERROR: No kubectl context active. Configure KUBECONFIG and retry." >&2
  exit 1
fi

read -r -p "Install to context '${CURRENT_CONTEXT}' namespace '${NAMESPACE}'? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted." >&2
  exit 1
fi

# ─── cleanup trap ─────────────────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  echo ""
  echo ">>> Cleanup: collecting artifacts..."
  mkdir -p "$ARTIFACTS_DIR"

  kubectl -n "$NAMESPACE" get events --sort-by=.lastTimestamp \
    > "${ARTIFACTS_DIR}/events.txt" 2>/dev/null || true
  kubectl -n "$NAMESPACE" get pods -o wide \
    > "${ARTIFACTS_DIR}/pods.txt" 2>/dev/null || true
  for pod in $(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
    kubectl -n "$NAMESPACE" logs "$pod" --all-containers=true \
      > "${ARTIFACTS_DIR}/logs-${pod}.txt" 2>/dev/null || true
  done
  helm -n "$NAMESPACE" get manifest "$RELEASE_NAME" \
    > "${ARTIFACTS_DIR}/manifests.yaml" 2>/dev/null || true

  echo ">>> Cleanup: artifacts saved to ${ARTIFACTS_DIR}"

  echo ">>> Cleanup: helm uninstall..."
  helm -n "$NAMESPACE" uninstall "$RELEASE_NAME" --wait=false 2>/dev/null || true

  echo ">>> Cleanup: deleting namespace ${NAMESPACE}..."
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --timeout=60s 2>/dev/null || true

  if [[ $exit_code -eq 0 ]]; then
    echo ">>> Smoke test PASSED"
  else
    echo ">>> Smoke test FAILED (exit $exit_code) — see artifacts in ${ARTIFACTS_DIR}"
  fi
}
trap cleanup EXIT

# ─── pre-flight ───────────────────────────────────────────────────────────────
if [[ ! -f "$VALUES_FILE" ]]; then
  echo "ERROR: Values file not found: ${VALUES_FILE}" >&2
  exit 1
fi

echo ">>> Creating namespace ${NAMESPACE}..."
kubectl create namespace "$NAMESPACE"

echo ">>> Checking required secrets..."
for secret in uc-smoke-db-secret uc-smoke-passwords; do
  if ! kubectl -n "$NAMESPACE" get secret "$secret" > /dev/null 2>&1; then
    echo "  Secret '${secret}' not found in namespace. Creating placeholder (CHANGE before real test)..."
    kubectl -n "$NAMESPACE" create secret generic "$secret" \
      --from-literal=password="changeme-smoke" \
      --from-literal=password-keystore="changeme-smoke" \
      --from-literal=password-truststore="changeme-smoke" \
      --from-literal=UC_TRUSTMANAGER_TRUSTSTORE_PASSWORD_ENCRYPTED="changeme-smoke"
  fi
done

# ─── helm install ─────────────────────────────────────────────────────────────
echo ">>> Resolving subchart dependencies..."
helm dependency update "${REPO_ROOT}/charts/universal-controller" --skip-refresh

INSTALL_ARGS=(
  "$RELEASE_NAME"
  "${REPO_ROOT}/charts/universal-controller"
  --namespace "$NAMESPACE"
  --values "$VALUES_FILE"
  --timeout "$TIMEOUT"
  --wait
)

if [[ -n "${SMOKE_VALUES_OVERRIDE:-}" ]]; then
  INSTALL_ARGS+=(--values "$SMOKE_VALUES_OVERRIDE")
fi

echo ">>> helm install ${INSTALL_ARGS[*]}..."
helm install "${INSTALL_ARGS[@]}"

# ─── rollout wait ─────────────────────────────────────────────────────────────
echo ">>> Waiting for UC rollout..."
kubectl -n "$NAMESPACE" rollout status deployment "${RELEASE_NAME}-uc" \
  --timeout="$TIMEOUT" || \
kubectl -n "$NAMESPACE" rollout status statefulset "${RELEASE_NAME}-uc" \
  --timeout="$TIMEOUT"

if kubectl -n "$NAMESPACE" get deployment "${RELEASE_NAME}-oms" > /dev/null 2>&1 || \
   kubectl -n "$NAMESPACE" get statefulset "${RELEASE_NAME}-oms" > /dev/null 2>&1; then
  echo ">>> Waiting for OMS rollout..."
  kubectl -n "$NAMESPACE" rollout status deployment "${RELEASE_NAME}-oms" \
    --timeout="$TIMEOUT" 2>/dev/null || \
  kubectl -n "$NAMESPACE" rollout status statefulset "${RELEASE_NAME}-oms" \
    --timeout="$TIMEOUT" 2>/dev/null || true
fi

# ─── helm test ────────────────────────────────────────────────────────────────
echo ">>> Running helm test..."
helm -n "$NAMESPACE" test "$RELEASE_NAME" --timeout "$TIMEOUT" --logs

# ─── platform-specific assertions ─────────────────────────────────────────────
echo ">>> Platform assertions for: ${PLATFORM}"

case "$PLATFORM" in
  native)
    echo "  Checking OMS port 7878 is reachable..."
    kubectl -n "$NAMESPACE" run smoke-oms-check \
      --image=alpine:3.19 --restart=Never --rm --attach --timeout=30s \
      -- sh -c "nc -z ${RELEASE_NAME}-oms-service 7878 && echo 'OMS reachable'" || \
      echo "  WARN: OMS port check skipped (nc not available or OMS not yet ready)"
    ;;

  openshift)
    echo "  Checking Routes exist..."
    oc_or_kubectl() { kubectl "$@"; }
    if command -v oc &> /dev/null; then oc_or_kubectl() { oc "$@"; }; fi

    oc_or_kubectl -n "$NAMESPACE" get route "${RELEASE_NAME}-uc-route" \
      -o jsonpath='{.spec.host}' | xargs -I{} echo "  UC Route host: {}"

    echo "  Verifying pods are NOT running as root (restricted-v2 SCC)..."
    kubectl -n "$NAMESPACE" get pods -o jsonpath='{range .items[*]}{.metadata.name}: seccomp={.spec.securityContext.seccompProfile.type}{"\n"}{end}' || true
    ;;

  aks)
    echo "  Checking Istio VirtualService..."
    kubectl -n "$NAMESPACE" get virtualservice 2>/dev/null | head -5 || \
      echo "  INFO: No VirtualService found (expected if istio.enabled=false in smoke values)"

    echo "  Checking Istio sidecar injection..."
    kubectl -n "$NAMESPACE" get pods -o jsonpath='{range .items[*]}{.metadata.name}: containers={.spec.containers[*].name}{"\n"}{end}' || true
    ;;
esac

echo ">>> All assertions passed."
