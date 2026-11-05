# GitHub Actions

Two workflows. The Pages one is the chart repository. The OCI one does not run on a normal push to `main`.

## workflows/publish-helm.yml

**Helm lint and publish.** Classic repo: `index.yaml` and `.tgz` files on the `gh-pages` branch.

| Event | What runs |
|-------|-----------|
| Pull request to `main` | `helm lint` on every chart under `charts/*/`. Dependencies are downloaded with `scripts/helm-dep-build.sh` first. |
| Pull request that changes a chart | One chart per PR. The title must start with `[<folder>] ` (for `charts/example`, `[example] …`). `version` in `Chart.yaml` must be higher than on `main`. A new chart is allowed. `starters/` and docs-only PRs skip this. |
| Push to `main` | Lint, then package only versions that are not already on `gh-pages`, merge them into `index.yaml`, and deploy. An unchanged version is skipped. Published versions are not deleted. |

After the first successful run, set **Settings → Pages** to branch `gh-pages`, folder `/`.

Details: [docs/02-publish-helm-workflow.md](../docs/02-publish-helm-workflow.md).

## workflows/publish-helm-oci.yml

**Helm push OCI.** Optional push to Docker Hub. It does not replace the Pages workflow.

| Event | What runs |
|-------|-----------|
| Tag `<chart name>-<version>` (for example `example-0.1.0`) | Package and `helm push` that one chart |
| Actions → **Helm push OCI** | Push one chart folder, or every chart if the input is empty |

The job fails until the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are set. A merge to `main` does not start this workflow.

Details: [docs/05-publish-helm-oci-workflow.md](../docs/05-publish-helm-oci-workflow.md).
