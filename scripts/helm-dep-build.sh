#!/usr/bin/env bash
# Download a chart's dependencies (Chart.yaml `dependencies:`) into <chart>/charts/
# so `helm lint` / `helm package` work. No-op for charts without dependencies.
# Used by the GitHub workflows; also handy locally before `helm package`.
#
# Usage: ./scripts/helm-dep-build.sh <chart-dir>
# Requires: helm, yq (mikefarah v4 — preinstalled on GitHub-hosted Ubuntu runners)

set -euo pipefail

DIR="${1:-}"
if [[ -z "$DIR" || ! -f "$DIR/Chart.yaml" ]]; then
  echo "Usage: $0 <chart-dir>  (directory containing Chart.yaml)" >&2
  exit 1
fi

if [[ "$(yq -r '.dependencies | length' "$DIR/Chart.yaml")" == "0" ]]; then
  exit 0
fi

# Older Helm 3 releases require HTTP(S) dependency repos to be known via `helm repo add`.
# oci:// and file:// repositories need no registration.
i=0
while IFS= read -r repo; do
  case "$repo" in
    http://*|https://*)
      i=$((i + 1))
      helm repo add "dep-$(basename "$DIR")-$i" "$repo" --force-update >/dev/null
      ;;
  esac
done < <(yq -r '.dependencies[].repository // ""' "$DIR/Chart.yaml")

echo "helm dependency build $DIR"
helm dependency build "$DIR"
