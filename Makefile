LEGACY_CHARTS := helm_ua_v1.5.1-aks helm_ua_v1.5.1-ocp helm_uac_v1.0-native helm_uac_v1.4.1-ocp helm_uac_v1.5-aks
NEW_CHARTS    := charts/universal-agent charts/universal-controller
CHARTS        := $(LEGACY_CHARTS)
RELEASE_NAME := ci-test

.PHONY: lint template golden golden-update unittest schema verify smoke bootstrap

## lint: Run helm lint on all charts (legacy + consolidated)
lint:
	@failed=0; \
	for chart in $(LEGACY_CHARTS) $(NEW_CHARTS); do \
		echo "--- helm lint $$chart ---"; \
		helm lint "$$chart" || failed=1; \
	done; \
	exit $$failed

## dep-update: Resolve subchart dependencies for consolidated charts
dep-update:
	helm dependency update charts/universal-controller

## template: Render all charts and validate with kubeconform (legacy + all new-chart platforms)
template:
	@failed=0; \
	for chart in $(LEGACY_CHARTS); do \
		echo "--- kubeconform $$chart ---"; \
		helm template $(RELEASE_NAME) "$$chart" | \
		  kubeconform -strict -ignore-missing-schemas -summary - || failed=1; \
	done; \
	for platform in aks native openshift; do \
		echo "--- kubeconform universal-agent:$$platform ---"; \
		helm template $(RELEASE_NAME) charts/universal-agent --set platform=$$platform | \
		  kubeconform -strict -ignore-missing-schemas -summary - || failed=1; \
		echo "--- kubeconform universal-controller:$$platform ---"; \
		helm template $(RELEASE_NAME) charts/universal-controller --set platform=$$platform | \
		  kubeconform -strict -ignore-missing-schemas -summary - || failed=1; \
	done; \
	exit $$failed

## golden: Diff rendered output against baseline snapshots in tests/golden/
golden:
	@changed=0; \
	for chart in $(LEGACY_CHARTS); do \
		helm template test-release "$$chart" > /tmp/golden-$$(echo $$chart | tr / -).yaml; \
		if ! diff -q "tests/golden/$${chart}/all.yaml" "/tmp/golden-$$(echo $$chart | tr / -).yaml" > /dev/null 2>&1; then \
			echo "CHANGED: $$chart"; diff "tests/golden/$${chart}/all.yaml" "/tmp/golden-$$(echo $$chart | tr / -).yaml" || true; changed=1; \
		else echo "OK: $$chart"; fi; \
	done; \
	for platform in aks native openshift; do \
		helm template test-release charts/universal-agent --set platform=$$platform > /tmp/ua-$$platform.yaml; \
		if ! diff -q "tests/golden/universal-agent/$${platform}.yaml" "/tmp/ua-$$platform.yaml" > /dev/null 2>&1; then \
			echo "CHANGED: universal-agent:$$platform"; diff "tests/golden/universal-agent/$${platform}.yaml" "/tmp/ua-$$platform.yaml" || true; changed=1; \
		else echo "OK: universal-agent:$$platform"; fi; \
		helm template test-release charts/universal-controller --set platform=$$platform > /tmp/uc-$$platform.yaml; \
		if ! diff -q "tests/golden/universal-controller/$${platform}.yaml" "/tmp/uc-$$platform.yaml" > /dev/null 2>&1; then \
			echo "CHANGED: universal-controller:$$platform"; diff "tests/golden/universal-controller/$${platform}.yaml" "/tmp/uc-$$platform.yaml" || true; changed=1; \
		else echo "OK: universal-controller:$$platform"; fi; \
	done; \
	for extra in native-statefulset aks-istio; do \
		case $$extra in \
			native-statefulset) flags="--set platform=native --set statefulSet.enabled=true" ;; \
			aks-istio)          flags="--set platform=aks --set istio.enabled=true" ;; \
		esac; \
		helm template test-release charts/universal-controller $$flags > /tmp/uc-$$extra.yaml; \
		if ! diff -q "tests/golden/universal-controller/$${extra}.yaml" "/tmp/uc-$$extra.yaml" > /dev/null 2>&1; then \
			echo "CHANGED: universal-controller:$$extra"; diff "tests/golden/universal-controller/$${extra}.yaml" "/tmp/uc-$$extra.yaml" || true; changed=1; \
		else echo "OK: universal-controller:$$extra"; fi; \
	done; \
	if [ "$$changed" = "1" ]; then echo ""; echo "Golden files differ. Run 'make golden-update' to accept."; exit 1; fi

## golden-update: Regenerate ALL golden snapshot files
golden-update:
	@for chart in $(LEGACY_CHARTS); do \
		mkdir -p "tests/golden/$$chart"; \
		helm template test-release "$$chart" > "tests/golden/$$chart/all.yaml"; \
		echo "Updated: tests/golden/$$chart/all.yaml"; \
	done; \
	for platform in aks native openshift; do \
		helm template test-release charts/universal-agent --set platform=$$platform > tests/golden/universal-agent/$${platform}.yaml; \
		echo "Updated: tests/golden/universal-agent/$${platform}.yaml"; \
		helm template test-release charts/universal-controller --set platform=$$platform > tests/golden/universal-controller/$${platform}.yaml; \
		echo "Updated: tests/golden/universal-controller/$${platform}.yaml"; \
	done; \
	helm template test-release charts/universal-controller --set platform=native --set statefulSet.enabled=true > tests/golden/universal-controller/native-statefulset.yaml; \
	echo "Updated: tests/golden/universal-controller/native-statefulset.yaml"; \
	helm template test-release charts/universal-controller --set platform=aks --set istio.enabled=true > tests/golden/universal-controller/aks-istio.yaml; \
	echo "Updated: tests/golden/universal-controller/aks-istio.yaml"

## unittest: Run helm unittest suites for consolidated charts
unittest:
	@failed=0; \
	for chart in $(NEW_CHARTS); do \
		echo "--- unittest $$chart ---"; \
		helm unittest "$$chart" || failed=1; \
	done; \
	exit $$failed

## schema: Validate values.yaml against values.schema.json
schema:
	@failed=0; \
	for chart in $(LEGACY_CHARTS) $(NEW_CHARTS); do \
		if [ -f "$$chart/values.schema.json" ]; then \
			echo "--- schema validate $$chart ---"; \
			helm lint "$$chart" --strict || failed=1; \
		else \
			echo "SKIP: $$chart (no values.schema.json)"; \
		fi; \
	done; \
	exit $$failed

## verify: Full local verification gate (lint + template + golden + unittest + schema)
verify: lint golden template unittest schema
	@echo "All verify checks passed."

## smoke: Run live smoke test against a real cluster (requires PLATFORM=native|openshift|aks)
smoke:
	@if [ -z "$(PLATFORM)" ]; then echo "Usage: make smoke PLATFORM=native|openshift|aks"; exit 1; fi
	bash scripts/smoke-test.sh $(PLATFORM)

## smoke-all: Run smoke tests across all configured platform contexts
smoke-all:
	bash scripts/smoke-test.sh native
	bash scripts/smoke-test.sh openshift
	bash scripts/smoke-test.sh aks

## bootstrap: Install pinned toolchain versions
bootstrap:
	bash scripts/bootstrap.sh

help:
	@grep -E '^## ' Makefile | sed 's/## //'
