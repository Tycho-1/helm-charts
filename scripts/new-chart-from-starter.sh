#!/usr/bin/env bash
# Generate a new Helm chart from a starter using `helm create -p <path>`.
# Safe for local use and CI (GitLab, GitHub Actions, etc.): no HELM_DATA_HOME copy needed.
#
# Usage:
#   ./scripts/new-chart-from-starter.sh <chart-name> [starter] [parent-dir]
#
# Examples:
#   ./scripts/new-chart-from-starter.sh my-api
#   ./scripts/new-chart-from-starter.sh my-api webapp-starter charts
#   ./scripts/new-chart-from-starter.sh my-api basic-starter /tmp/out
#
# Defaults: starter=webapp-starter, parent-dir=charts (relative to repo root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STARTERS_DIR="$REPO_ROOT/starters"

CHART_NAME="${1:-}"
STARTER="${2:-webapp-starter}"
PARENT_DIR="${3:-charts}"

if [[ -z "$CHART_NAME" ]]; then
  echo "Usage: $0 <chart-name> [starter] [parent-dir]" >&2
  echo "  starter:  webapp-starter | basic-starter (default: webapp-starter)" >&2
  echo "  parent-dir: directory for the new chart (default: charts)" >&2
  exit 1
fi

STARTER_PATH="$STARTERS_DIR/$STARTER"
if [[ ! -d "$STARTER_PATH" ]]; then
  echo "Starter not found: $STARTER_PATH" >&2
  exit 1
fi

if [[ "$PARENT_DIR" = /* ]]; then
  OUT_BASE="$PARENT_DIR"
else
  OUT_BASE="$REPO_ROOT/$PARENT_DIR"
fi
mkdir -p "$OUT_BASE"
TARGET="$OUT_BASE/$CHART_NAME"

if [[ -e "$TARGET" ]]; then
  echo "Refusing to overwrite existing path: $TARGET" >&2
  exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is not on PATH" >&2
  exit 1
fi

# helm create writes <chart-name> inside the current working directory
cd "$OUT_BASE"
helm create "$CHART_NAME" -p "$STARTER_PATH"
echo "Created: $TARGET"
echo "Next: edit $TARGET/Chart.yaml and values.yaml, then helm lint $TARGET"
