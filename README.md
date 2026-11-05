# Tycho-1 Helm charts

[![Helm](https://img.shields.io/badge/Helm-chart_repository-0F1689?logo=helm&logoColor=white)](https://helm.sh/docs/topics/chart_repository/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-charts-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Personal Helm chart repository, served from GitHub Pages.

## Charts

| Chart | Description |
|-------|-------------|
| [example](charts/example) | Minimal demo chart (a single ConfigMap) |

## Usage

```bash
helm repo add tycho-1 https://tycho-1.github.io/helm-charts/
helm repo update
helm search repo tycho-1/
helm install my-release tycho-1/<chart> --version <version>
```

## Repository layout

```
.github/workflows/   CI: lint + publish to gh-pages, optional OCI push to Docker Hub
charts/<name>/       charts that are published (one folder per chart)
starters/            templates for new charts — never published
scripts/             new-chart-from-starter.sh, helm-dep-build.sh
docs/                guides: hosting, workflows, OCI, Artifact Hub
```

## Updating a chart

Change the chart, check it, then bump the version. The version bump is the release step, after `helm lint` and `helm template` succeed.

1. **Make the change** in `charts/my-app/` (`templates/`, `values.yaml`, and `Chart.yaml` fields other than `version`).
2. **Check it locally:**

   ```bash
   ./scripts/helm-dep-build.sh charts/my-app   # only when Chart.yaml lists dependencies
   helm lint charts/my-app
   helm template test charts/my-app
   ```

3. **Release the change.** Raise `version` in `Chart.yaml` and add a changelog entry ([docs/03-chart-changelog.md](docs/03-chart-changelog.md)).
4. Open a pull request to `main` for **one** chart. The title must start with `[<folder>] ` (for `charts/my-app`, `[my-app] …`). CI lints every chart and fails unless `version` is higher than on `main`.
5. Merge. CI packages only chart versions that are not on `gh-pages` yet, merges them into `index.yaml`, and deploys. An unchanged version is skipped. Published versions are never overwritten or removed.

**New chart.** Create it from a starter. The script replaces the `<CHARTNAME>` placeholder:

```bash
./scripts/new-chart-from-starter.sh my-app            # webapp-starter
./scripts/new-chart-from-starter.sh my-app basic-starter
```

The starter is only a starting point. After the script, edit the new chart where the defaults do not match the application: image, ports, probes, resources, and any optional features. Then follow the update steps above.

Any change to a published chart needs a new `version` — if you push straight to `main` without a bump, the change is skipped (not published).

**Optional OCI (Docker Hub):** push a tag `<chart name>-<version>` (e.g. `my-app-0.1.0`) to also `helm push` that chart — see [docs/05-publish-helm-oci-workflow.md](docs/05-publish-helm-oci-workflow.md).

## Documentation

[docs/README.md](docs/README.md)

## License

[MIT](LICENSE)
