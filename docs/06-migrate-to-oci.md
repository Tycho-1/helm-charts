# 06. Migrating a Helm chart repository to OCI

Migration from an **HTTP chart repository** (`index.yaml` + `.tgz`, `helm repo add`) to **OCI** (`helm push` / `helm install oci://…`).

This repository supports **both** models:

| Model | Workflow | Output |
|--------|----------|--------|
| **Classic** | [`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml) | GitHub Pages — `index.yaml` + `.tgz` |
| **OCI** | [`.github/workflows/publish-helm-oci.yml`](../.github/workflows/publish-helm-oci.yml) | Docker Hub — `helm push` |

A full cutover is not required. Both publishing paths can run in parallel. Move consumers chart by chart, then retire the classic repository when nothing depends on it.

**Related docs**

- [docs/04-helm-oci.md](04-helm-oci.md) — OCI concepts, Docker Hub path rules, local testing
- [docs/02-publish-helm-workflow.md](02-publish-helm-workflow.md) — classic GitHub Pages publish workflow
- [docs/05-publish-helm-oci-workflow.md](05-publish-helm-oci-workflow.md) — OCI publish workflow (tags, secrets)
- [docs/07-artifact-hub.md](07-artifact-hub.md) — listing charts on Artifact Hub (HTTP and OCI)

Official Helm reference: [Use OCI-based registries](https://helm.sh/docs/topics/registries/).

---

## Recommended approach

```text
charts/*  ──►  publish-helm.yml      ──►  GitHub Pages (index.yaml)  ──►  legacy consumers
          └──►  publish-helm-oci.yml  ──►  Docker Hub (OCI)         ──►  OCI consumers
```

1. **Enable OCI publishing** alongside the existing classic workflow.
2. **Smoke-test** one chart end to end.
3. **Migrate consumers** one at a time.
4. **Deprecate** the classic repo URL.
5. **Disable** classic publish when the last consumer has moved.

---

## Phase 0 — Decide scope (before changing anything)

### 1. Pick your OCI registry

| Registry | Good if… | Watch out for |
|----------|----------|---------------|
| **Docker Hub** (this repo’s OCI workflow) | Simple public charts, one namespace per user/org | **`helm push`** path is **namespace only** — see [04-helm-oci.md § Docker Hub](04-helm-oci.md#docker-hub-hostname-vs-profile-url-vs-username) |
| **GHCR** | Same org as GitHub, private packages | Needs `write:packages` PAT; duplicate the workflow with `ghcr.io` login |
| **ECR / ACR / Harbor** | You already push container images there | Path depth rules differ from Docker Hub |

This repo’s OCI workflow targets **Docker Hub** only. For other registries, copy the workflow and change `helm registry login` and the `oci://` URL — see [05-publish-helm-oci-workflow.md § Other registries](05-publish-helm-oci-workflow.md#other-registries-ghcr-ecr-).

### 2. Public vs private

- A **classic GitHub Pages** repo is usually **public** — anyone can `helm repo add`.
- A **private OCI** registry requires **`helm registry login`** on every laptop and CI job that installs charts.

### 3. Inventory consumers

List every place that runs:

```bash
helm repo add …
helm install myrepo/<chart> --version …
```

Also check:

- **Argo CD** / **Flux** (GitOps)
- **Terraform** `helm_release`
- **CI pipelines** and internal runbooks
- **Artifact Hub** (if you list charts there)

---

## Phase 1 — Prepare publishing (maintainer side)

### What stays the same

- Chart **source** in git (`charts/*/`, `Chart.yaml`, templates, values)
- **`helm package`**
- **Version bumps** in `Chart.yaml`
- **Lint / test** (`helm lint`, `helm template`, etc.)

### What changes

| Classic | OCI |
|---------|-----|
| `helm repo index` | **Not needed** |
| Upload to static host / `gh-pages` | **`helm push oci://…`** |
| Publish all charts on every merge to `main` | **Per-chart git tag** (`example-0.1.0`) or manual workflow dispatch |
| Delete = remove `.tgz` + regenerate `index.yaml` | Delete = remove **tag** in registry UI or with **`crane`** / **`regctl`** |

### Steps for this repo

1. Add secrets **`DOCKERHUB_USERNAME`** and **`DOCKERHUB_TOKEN`** under **Settings → Secrets and variables → Actions**.
2. Optional: set variable **`DOCKERHUB_NAMESPACE`** if the Hub namespace differs from your Docker ID.
3. **Smoke-test** — **Actions → Helm push OCI → Run workflow** → **Chart** = `example`, or follow [Test locally (before CI)](04-helm-oci.md#test-locally-before-ci) in 04-helm-oci.md.
4. Confirm naming:
   - Folder: `charts/example`
   - `Chart.yaml`: `name: example`, `version: 0.1.0`
   - Docker Hub repo: `YOUR_ID/example`, tag: `0.1.0`
5. Use **Helm ≥ 3.18.2** for Docker Hub (401 bug in 3.18.0). The OCI workflow pins **3.18.3**.

### Release model shift (important)

**Classic** ([`publish-helm.yml`](../.github/workflows/publish-helm.yml)):

- Merge to **`main`** → chart versions not yet on `gh-pages` are packaged and merged into `index.yaml`. An unchanged version is skipped.

**OCI** ([`publish-helm-oci.yml`](../.github/workflows/publish-helm-oci.yml)):

- Git tag **`payments-api-2.0.0`** (chart **`name`** + **`version`** from `Chart.yaml`) → **only that chart** is pushed.
- Unrelated tags (e.g. **`v1.0.0`**) do **not** trigger the workflow (filter: `*-*.*.*`).
- Avoid re-pushing the same version tag — registries treat tags as immutable.

**Convention:** Keep each chart’s **folder name** under `charts/` the same as **`name:`** in **`Chart.yaml`**. Git tags use **`name`** and **`version`** from **`Chart.yaml`**. The manual **Chart** input is the folder name.

---

## Phase 2 — Migrate consumers

### Install commands

**Before (classic):**

```bash
helm repo add myorg https://myorg.github.io/my-helm-repo/
helm repo update
helm install myrelease myorg/example --version 0.1.0
```

**After (OCI, Docker Hub):**

```bash
# Private registry only:
helm registry login docker.io -u YOUR_DOCKER_ID

helm install myrelease oci://docker.io/YOUR_DOCKER_ID/example --version 0.1.0
```

There is no **`helm repo add`** or **`helm repo update`**. Pin versions with **`--version`** (OCI tag = chart version).

### What consumers must update

| Area | Classic | OCI |
|------|---------|-----|
| Discovery | `index.yaml`, `helm search repo` | Known `oci://` URL + registry tags / UI |
| Auth | Often none (public HTTP) | **`helm registry login`** in CI and on dev machines |
| CI | `helm repo add` step | `helm registry login` + full `oci://…/chart` URL |
| Pinning | `--version 0.1.0` | Same |
| Upgrade | `helm upgrade … myorg/chart` | `helm upgrade … oci://…/chart` |

### GitOps (Argo CD / Flux)

- **Argo CD** supports OCI Helm sources; the Application spec changes from an HTTP `repoURL` to an OCI reference. Confirm your Argo CD version supports OCI Helm charts.
- **Flux** uses different resource types for HTTP repos vs OCI — plan manifest updates per app.

Migrate **one application at a time**, not the whole estate in a single change.

### Chart dependencies (`Chart.yaml`)

If charts depend on other charts in your org, update dependency **`repository`** fields:

```yaml
dependencies:
  - name: shared-lib
    version: "1.2.0"
    repository: "oci://docker.io/myorg"   # push path: namespace only; Helm resolves chart name
```

Run **`helm dependency update`** and **`helm package`** locally before relying on CI.

---

## Phase 3 — Discovery, docs, and tooling

### Differences from a classic repository

- A single **`index.yaml`** listing all charts and versions
- **`helm search repo`** against one repo alias
- “Browse all charts” via one HTTPS URL

### Mitigations

| Need | Option |
|------|--------|
| Human discovery | README table of `oci://…` URLs; internal docs |
| Catalog | [Artifact Hub](07-artifact-hub.md) (OCI has separate setup from HTTP repos) |
| Automation | Registry API; tools like **`crane ls`** |
| Transition period | Keep the classic repo running in parallel |

---

## Phase 4 — Security and operations

### Auth and secrets

- Use **access tokens** (Docker Hub PAT, GHCR PAT with `write:packages`) — not account passwords when 2FA is enabled.
- Scope CI secrets: push for publish workflow; read-only tokens for consumer CI where possible.
- Document **`helm registry login`** for developers.

### Immutability

- Do **not** overwrite an published OCI tag with different chart content.
- To fix a bad release: bump **`version`** in `Chart.yaml` (e.g. `0.1.1`) and publish a **new** tag.

### Deletion

- Helm has **no** remote delete command.
- Removing a tag breaks anyone pinning **`--version`** to that tag — coordinate before deleting production versions. See [Removing published charts](04-helm-oci.md#removing-published-charts-from-the-registry) in 04-helm-oci.md.

### Rate limits and cost

- Docker Hub free tier has pull/push limits.
- GHCR usage depends on your GitHub plan.
- Plan accordingly if many clusters pull charts frequently.

### Air-gapped / mirrored environments

- **Classic:** mirror `index.yaml` + `.tgz` to an internal HTTP server — well understood.
- **OCI:** mirror with **`helm pull`** + re-push, or registry replication (Harbor, etc.).
- Validate the mirror story **before** cutover if you have air-gapped clusters.

---

## Phase 5 — Cutover checklist

### Pre-cutover (parallel period)

- [ ] OCI workflow tested for at least one chart (e.g. `example`)
- [ ] At least one consumer installed successfully from `oci://…`
- [ ] CI/CD pipelines updated and tested
- [ ] GitOps applications updated (if applicable)
- [ ] Runbooks and install docs updated
- [ ] Artifact Hub updated (if used)
- [ ] Team knows **`helm registry login`** and OCI install URLs

### Cutover

- [ ] Announce deprecation date for the classic **`helm repo add`** URL
- [ ] Publish final/active chart versions to OCI (one tag per release)
- [ ] Switch all consumer configs to OCI URLs
- [ ] Monitor installs for one or two release cycles

### Post-cutover (decommission classic)

- [ ] Disable or remove [`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml) (or stop publishing chart bumps via `main`)
- [ ] Leave `gh-pages` read-only for a grace period, or add a redirect notice
- [ ] Remove classic **`helm repo add`** instructions from team docs
- [ ] Archive old `.tgz` files if compliance requires retention

---

## Operational notes

1. **Docker Hub push path** — use **`oci://docker.io/<namespace>`** only; Helm appends the chart **`name`**. Putting the chart name in the push URL often causes a **401** that looks like bad credentials.
2. **Release model** — OCI publishing here is **tag-driven per chart**, not “every merge to `main` republishes everything.”
3. **Folder name = `Chart.yaml` `name:`** — tags use **`name`** and **`version`** from **`Chart.yaml`**. Keep the chart folder name the same as **`name:`**.
4. **Consumer rewrites** — every **`helm repo add`** / **`myrepo/chart`** reference must change to **`oci://…/chart`**.
5. **Private registry auth** — CI and laptops need **`helm registry login`**; classic public HTTP often required none.
6. **No central index** — plan how people discover charts without **`index.yaml`**.
7. **Chart dependencies** — update **`repository:`** to **`oci://…`** and re-test **`helm dependency update`**.
8. **GitOps** — Argo CD / Flux manifest changes; verify OCI support for your versions.
9. **Tag immutability** — never overwrite a published tag; bump chart **`version`** instead.
10. **Helm version** — Docker Hub needs **≥ 3.18.2**; align local, CI, and consumer Helm versions.

---

## Suggested timeline (example)

| Week | Activity |
|------|----------|
| 1 | Enable OCI secrets; smoke-test `example`; document OCI install URLs |
| 2–3 | Parallel publish: classic on `main` + OCI on chart tags |
| 4–6 | Migrate internal consumers; update CI and GitOps |
| 7 | Deprecation notice for classic repo URL |
| 8+ | Disable classic publish; OCI only |

Adjust the pace to your number of charts and downstream teams. A single chart and one consumer can move faster; a large monorepo with many dependents should keep the parallel period longer.

---

## First steps

1. Run **Actions → Helm push OCI** with **Chart** = `example`, or test locally — [Test locally (before CI)](04-helm-oci.md#test-locally-before-ci).
2. From a test cluster: **`helm install … oci://docker.io/YOUR_ID/example --version 0.1.0`**.
3. List every repo and script that uses your GitHub Pages **`helm repo add`** URL.
4. Pick one low-risk consumer to migrate first.
5. Keep **[`publish-helm.yml`](../.github/workflows/publish-helm.yml)** running until the last consumer leaves the classic URL.

---

## Quick reference

| Action | Classic HTTP repo | OCI registry |
|--------|-------------------|--------------|
| Publish | `helm package` + `helm repo index` + upload | `helm package` + **`helm push`** |
| Configure client | `helm repo add` + `helm repo update` | **`helm registry login`** (if private) |
| Install | `helm install rel myrepo/chart --version x.y.z` | **`helm install rel oci://registry/…/chart --version x.y.z`** |
| Remove version | Remove `.tgz`, regenerate **`index.yaml`** | Delete **tag** in registry UI or CLI |
| This repo’s CI | Merge to **`main`** | Tag **`name-version`** or manual dispatch |
