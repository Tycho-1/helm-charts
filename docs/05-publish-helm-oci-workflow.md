# 05. OCI publish workflow

Reference for [`.github/workflows/publish-helm-oci.yml`](../.github/workflows/publish-helm-oci.yml). The workflow packages charts under `charts/*/` and runs `helm push` to Docker Hub (`oci://docker.io/<namespace>`). It does not replace [`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml) (GitHub Pages and `index.yaml`).

---

## Many charts in one repo (monorepo)

You **do not** need one git commit per chart. **One commit** can bump **`version`** in a **single** `Chart.yaml` (the chart you’re releasing). If you release **two** charts at once, you can use **one commit** with two `Chart.yaml` edits or **two commits** — both are fine.

### OCI (this workflow): use a **per-chart git tag**

To push **only** the chart that reached v2 (and avoid **`helm push`** failing because other charts’ versions already exist on Hub), use a tag that matches **[chart `name`]-[chart `version`]** from that chart’s **`Chart.yaml`** — the same convention as **[Chart Releaser](https://github.com/helm/chart-releaser)**:

| `Chart.yaml` | Git tag to create and push |
|----------------|----------------------------|
| `name: payments-api`, `version: 2.0.0` | **`payments-api-2.0.0`** |

```bash
git add charts/payments-api/Chart.yaml
git commit -m "chore: payments-api 2.0.0"
git tag payments-api-2.0.0
git push origin main
git push origin payments-api-2.0.0
```

The workflow finds **exactly one** chart whose **`name`** and **`version`** match the tag and **`helm push`**es **only** that chart.

**Avoid** a single tag like **`v2.0.0`** for the whole repo when you have multiple charts — the workflow would not know which chart released.

### Manual run (Actions UI)

- **Chart** field = folder name under **`charts/`** (e.g. **`example`**) → push **only** that chart.
- **Chart** left **empty** → push **every** chart (useful for a one-off test; not typical for Hub if many charts already exist).

---

## GitHub Pages (classic repo index)

[`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml) runs on **merge to `main`** and packages only chart **versions not yet on `gh-pages`**, then merges them into the existing **`index.yaml`**. Charts you did **not** bump are skipped; previously published versions stay available.

So: **one chart bumped to v2** → **one commit to `main`** adds that one package to the Pages site. You do **not** need separate commits per chart for Pages.

If you need **release-only** publishing (only when a tag is pushed) or **per-chart GitHub Releases**, consider **[helm/chart-releaser-action](https://github.com/helm/chart-releaser-action)** — it is built for monorepos.

---

## When the OCI workflow runs

| Trigger | What happens |
|---------|----------------|
| **`git push` of a chart-release tag** | Tag must equal **`<name>-<version>`** for **one** chart (see above), e.g. **`example-0.1.0`**. Only that chart is pushed to Docker Hub. The workflow listens for tags matching **`*-*.*.*`** — so **`v1.0.0`** and other non-chart tags do **not** start a run. |
| **`workflow_dispatch`** | Optional **Chart** input to push one folder, or empty to push all. Best for a first test (see [Test locally (before CI)](04-helm-oci.md#test-locally-before-ci) in 04-helm-oci.md). |

**Folder vs chart name:** The manual **Chart** input is the **folder name** under **`charts/`**. Git tags use **`name:`** from **`Chart.yaml`**. Packaging works either way, but keeping them the same (e.g. folder **`example`**, **`name: example`**) avoids confusion.

---

## Secrets and variables

| Name | Required | Purpose |
|------|----------|---------|
| **`DOCKERHUB_USERNAME`** | Yes | Docker ID; also used as default **`oci://docker.io/<user>`** namespace. |
| **`DOCKERHUB_TOKEN`** | Yes | [Docker Hub access token](https://docs.docker.com/security/for-developers/access-tokens/) with permission to push to your repos. |
| **`DOCKERHUB_NAMESPACE`** (repo **variable**) | No | If your Hub **namespace** differs from your Docker ID (e.g. org), set this; otherwise the workflow uses **`DOCKERHUB_USERNAME`**. |

Configure under **Settings → Secrets and variables → Actions**.

---

## Helm version

The workflow pins **Helm v3.18.3** (Docker Hub registry login compatibility). Adjust **`azure/setup-helm`** `version` if you standardize on another 3.x release.

---

## Other registries (GHCR, ECR, …)

This workflow targets **Docker Hub** only. To publish elsewhere, duplicate the workflow and change **`helm registry login`** and **`helm push … oci://…`**.

See [docs/04-helm-oci.md](04-helm-oci.md) for Docker Hub path rules (**namespace only** for `helm push`).

---

## Related

- [docs/04-helm-oci.md](04-helm-oci.md) — **`helm push`** on Docker Hub, login, delete
- [docs/06-migrate-to-oci.md](06-migrate-to-oci.md) — migration plan from classic repo to OCI
- [docs/02-publish-helm-workflow.md](02-publish-helm-workflow.md) — classic **GitHub Pages** publish workflow
