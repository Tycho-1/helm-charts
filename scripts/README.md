# Scripts

Helpers for creating charts and for building chart dependencies. Both need `helm` on `PATH`. `helm-dep-build.sh` also needs `yq` (mikefarah v4, which GitHub-hosted Ubuntu runners already have).

## new-chart-from-starter.sh

Create a chart from a starter with `helm create -p`. Helm replaces the `<CHARTNAME>` placeholder, so the new chart gets its own helper names. The starter does not have to be installed under `HELM_DATA_HOME`.

```bash
./scripts/new-chart-from-starter.sh <chart-name> [starter] [parent-dir]
```

| Argument | Default | Meaning |
|----------|---------|---------|
| `chart-name` | required | Directory name of the new chart |
| `starter` | `webapp-starter` | `webapp-starter` or `basic-starter` |
| `parent-dir` | `charts` | Where to create it. A relative path is from the repo root; an absolute path is used as given |

```bash
./scripts/new-chart-from-starter.sh my-app
./scripts/new-chart-from-starter.sh my-app basic-starter
./scripts/new-chart-from-starter.sh my-app webapp-starter /tmp/out
```

The script refuses to overwrite an existing directory. Next step: edit `Chart.yaml` and `values.yaml`, then `helm lint` the new chart.

## helm-dep-build.sh

Download dependencies listed in `Chart.yaml` into `<chart>/charts/` so `helm lint` and `helm package` succeed. Charts with no `dependencies:` entry are left unchanged.

```bash
./scripts/helm-dep-build.sh <chart-dir>
```

```bash
./scripts/helm-dep-build.sh charts/my-app
```

For each `http://` or `https://` dependency repository it runs `helm repo add` (older Helm 3 will not fetch from an unknown HTTPS repo). `oci://` and `file://` repositories are left to Helm. Then it runs `helm dependency build`.

The lint job, the GitHub Pages publish job, and the OCI workflow call this before lint or package. Locally you only need it when the chart declares dependencies.
