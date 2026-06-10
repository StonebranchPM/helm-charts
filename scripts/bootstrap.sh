#!/usr/bin/env bash
# Bootstrap pinned toolchain versions for Helm chart development.
# Run once per environment. Re-run safely (idempotent checks).
set -euo pipefail

HELM_VERSION="3.18.1"
CT_VERSION="3.12.0"
KIND_VERSION="0.26.0"
KUBECTL_VERSION="1.32.0"
HELM_DOCS_VERSION="1.14.2"
KUBECONFORM_VERSION="0.6.7"
KUBE_SCORE_VERSION="1.19.0"
YAMLLINT_VERSION="1.35.1"
HELM_UNITTEST_VERSION="0.7.2"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

BIN_DIR="${HOME}/.local/bin"
mkdir -p "$BIN_DIR"

need_install() {
  local cmd="$1" version_flag="${2:---version}" expected="$3"
  if command -v "$cmd" &>/dev/null; then
    actual=$("$cmd" $version_flag 2>&1 | head -1 || true)
    if echo "$actual" | grep -qF "$expected"; then
      echo "  $cmd $expected already installed"
      return 1
    fi
  fi
  return 0
}

echo "==> Helm $HELM_VERSION"
if need_install helm version "$HELM_VERSION"; then
  curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-${OS}-${ARCH}.tar.gz" | tar xz -C /tmp
  install -m 755 "/tmp/${OS}-${ARCH}/helm" "$BIN_DIR/helm"
fi

echo "==> chart-testing (ct) $CT_VERSION"
if need_install ct version "$CT_VERSION"; then
  curl -fsSL "https://github.com/helm/chart-testing/releases/download/v${CT_VERSION}/chart-testing_${CT_VERSION}_${OS}_${ARCH}.tar.gz" | tar xz -C /tmp
  install -m 755 /tmp/ct "$BIN_DIR/ct"
fi

echo "==> kind $KIND_VERSION"
if need_install kind version "$KIND_VERSION"; then
  curl -fsSL "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}" -o "$BIN_DIR/kind"
  chmod 755 "$BIN_DIR/kind"
fi

echo "==> kubectl $KUBECTL_VERSION"
if need_install kubectl version "$KUBECTL_VERSION"; then
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl" -o "$BIN_DIR/kubectl"
  chmod 755 "$BIN_DIR/kubectl"
fi

echo "==> helm-docs $HELM_DOCS_VERSION"
if need_install helm-docs version "$HELM_DOCS_VERSION"; then
  curl -fsSL "https://github.com/norwoodj/helm-docs/releases/download/v${HELM_DOCS_VERSION}/helm-docs_${HELM_DOCS_VERSION}_${OS}_${ARCH}.tar.gz" | tar xz -C /tmp
  install -m 755 /tmp/helm-docs "$BIN_DIR/helm-docs"
fi

echo "==> kubeconform $KUBECONFORM_VERSION"
if need_install kubeconform -v "$KUBECONFORM_VERSION"; then
  curl -fsSL "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-${OS}-${ARCH}.tar.gz" | tar xz -C /tmp
  install -m 755 /tmp/kubeconform "$BIN_DIR/kubeconform"
fi

echo "==> kube-score $KUBE_SCORE_VERSION"
if need_install kube-score version "$KUBE_SCORE_VERSION"; then
  curl -fsSL "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION}_${OS}_${ARCH}.tar.gz" | tar xz -C /tmp
  install -m 755 /tmp/kube-score "$BIN_DIR/kube-score"
fi

echo "==> yamllint $YAMLLINT_VERSION"
if ! command -v yamllint &>/dev/null || ! yamllint --version 2>&1 | grep -qF "$YAMLLINT_VERSION"; then
  pip install --quiet "yamllint==${YAMLLINT_VERSION}" || pip3 install --quiet "yamllint==${YAMLLINT_VERSION}"
fi

echo "==> helm-unittest plugin $HELM_UNITTEST_VERSION"
if ! helm plugin list 2>/dev/null | grep -q unittest; then
  helm plugin install https://github.com/helm-unittest/helm-unittest --version "$HELM_UNITTEST_VERSION"
else
  echo "  helm-unittest already installed"
fi

echo ""
echo "==> Verification"
helm version
ct version || echo "ct: WARN not in PATH — add $BIN_DIR to PATH"
kind version || echo "kind: WARN not in PATH"
kubectl version --client=true || echo "kubectl: WARN not in PATH"
echo ""
echo "Bootstrap complete. If tools are missing from PATH, add to your shell profile:"
echo "  export PATH=\"${BIN_DIR}:\$PATH\""
