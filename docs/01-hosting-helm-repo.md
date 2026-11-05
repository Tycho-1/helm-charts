# 01. Hosting a Helm chart repository

This document describes how charts are **packaged**, **published**, and **installed** from a classic chart repository. It complements the Helm documentation: [The Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/).

---

## Chart repository

A **classic Helm chart repository** is:

- An **HTTP(S) URL** that serves a file named **`index.yaml`**
- Plus **packaged charts** (`.tgz` files), usually on the same host
- Helm clients use `helm repo add` / `helm repo update` to discover charts from `index.yaml`

> **Alternative:** Helm also supports **OCI registries** (same idea as container images: `helm push` / `helm install oci://...`). Many teams prefer OCI for one registry for images and charts. This document covers the **HTTP + index.yaml** model; see [Use OCI-based registries](https://helm.sh/docs/topics/registries/).
>
> **Docker Hub:** For **`helm push`**, use **`oci://docker.io/<your-docker-id>`** and **nothing else** after the username (no chart name in the URL — Helm adds it from `Chart.yaml`). If you repeat the chart name in the path, Docker Hub sees an invalid repository name and you may get a **401** that looks like an auth problem. Details: [docs/04-helm-oci.md](04-helm-oci.md#docker-hub-hostname-vs-profile-url-vs-username).

---

## Source files and generated files

For a **classic HTTP chart repository**, you only **author** the chart **source** in git (plus optional CI, hosting config, etc.). You do **not** hand-write `index.yaml` or the `.tgz` archives.

| You maintain (by hand) | Produced by Helm commands |
|------------------------|---------------------------|
| Chart directory: `Chart.yaml`, `values.yaml`, `templates/*`, optional `charts/` deps, tests | **`helm package`** → `name-version.tgz` |
| Nothing else is required for a minimal repo | **`helm repo index`** → `index.yaml` listing all `.tgz` in a folder |

**Optional files** (not from Helm): `.gitignore` (ignore `*.tgz` if you do not commit packages), GitHub Actions / CI that runs `helm package` and `helm repo index`, or a `publish/` staging directory. **Chart Releaser** and similar tools automate package + index + upload.

This repo includes a minimal chart under **`charts/example/`** so you can see the folder layout. From the repo root:

```bash
helm lint charts/example
helm package charts/example
# → example-0.1.0.tgz (gitignored by default)
```

### Suggested repository layout

- **`starters/`** — copy these to create new charts (or use `helm create -p …/starters/<name>`). Not published as chart packages by default.
- **`charts/`** — your **actual** charts (created from a starter or authored here). CI packages **only** `charts/*/`.

```
.
├── .gitignore
├── README.md
├── starters/                  # templates — see [starters/README.md](../starters/README.md)
│   ├── basic-starter/
│   └── webapp-starter/
└── charts/                    # charts you ship / publish
    └── example/               # minimal sample (optional)
```

**Published** artifacts (often **not** on `main`, or only on `gh-pages` / object storage): `index.yaml` + `*.tgz`. Those are **outputs**, not something you normally write by hand.

---

## Adding a chart

Committing a new directory such as `charts/my-api/` only updates your **git repository** (the **source** of charts). It does **not** by itself update the **Helm chart repository** that users add with `helm repo add`. That public repo is just **`index.yaml` + `*.tgz` files** at an HTTPS URL.

| Question | Answer |
|----------|--------|
| **If I add `charts/new-chart/` and push to GitHub, is it in my Helm repo?** | **No**, not until you **package**, **rebuild the index**, and **upload** those artifacts to wherever the repo is hosted (Pages, S3, etc.). |
| **Do I need GitHub Actions?** | **No.** Actions are **optional**. They automate the same steps you can run locally or in any CI. |
| **When are Actions useful?** | When you want **every merge or tag** to publish `index.yaml` + packages **without** running Helm commands by hand. |

### Path A — Manual (no GitHub Actions)

You (or any CI you prefer) run Helm whenever you **add a chart** or **release a new version**:

1. **Add the chart** under `charts/<name>/` with a valid `Chart.yaml` (`name`, `version`, …).
2. **Package** every chart you want in the repo (including the new one):

   ```bash
   helm package charts/example
   helm package charts/my-new-chart
   ```

   Each command writes `name-version.tgz` in the **current directory** (unless you use `--destination`).

3. **Collect all `.tgz` files** you intend to publish into **one directory** (e.g. `publish/` or a temp folder). That folder should contain **every** chart package that should appear in the index (not only the new chart), because `helm repo index` builds the index from **whatever `.tgz` files are in that folder**.

4. **Regenerate `index.yaml`** with your real public base URL:

   ```bash
   mkdir -p publish
   mv *.tgz publish/   # or copy all packages into publish/
   helm repo index publish --url https://YOUR_USER.github.io/YOUR_REPO
   ```

5. **Upload** the contents of `publish/` (`index.yaml` + all `.tgz`) to your host (GitHub Pages branch, S3, etc.).

**Updating an existing remote repo:** If you already have an `index.yaml` online and only want to **add** packages without rebuilding from scratch locally, you can download the current `index.yaml` and use **`helm repo index --merge`** — see `helm repo index --help`.

### Path B — GitHub Actions (automation)

You **still** add chart folders in git the same way. Automation runs **`helm lint`**, **`helm package`**, and **`helm repo index`**, then uploads the result (for example to **`gh-pages`**).

**This repository includes** [`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml):

- **Pull requests** targeting `main`: **`helm lint`** on every chart under **`charts/*/`** only (not **`starters/`**), and a check that fails if a chart changed without a **`version`** bump in its `Chart.yaml`.
- **Pushes** to `main`: lint, package only chart **versions not yet on `gh-pages`**, merge them into the existing **`index.yaml`** (base URL `https://<owner>.github.io/<repo>/`), then deploy to the **`gh-pages`** branch via [peaceiris/actions-gh-pages](https://github.com/peaceiris/actions-gh-pages). Previously published versions are kept, so users pinned to an old version keep working.

**How the workflow is built** (triggers, jobs, `actions/checkout`, `setup-helm`, permissions, `GITHUB_TOKEN`, variables): [docs/02-publish-helm-workflow.md](02-publish-helm-workflow.md).

One-time GitHub setup: **Settings → Pages → Build and deployment → Source = branch `gh-pages`, folder `/`**. Your repo URL for `helm repo add` is `https://<owner>.github.io/<repo>/` (unless you set a **custom domain**; then set repository variable **`HELM_PAGES_BASE_URL`** to that HTTPS base URL with a trailing slash).

**Alternative (release-based):** [Chart Releaser Action](https://github.com/helm/chart-releaser-action) follows the [Helm how-to](https://helm.sh/docs/howto/chart_releaser_action/) — it usually creates **GitHub Releases** when **`version`** in `Chart.yaml` changes, and stores packages as release assets. Use Chart Releaser if you want GitHub Releases per chart version; use this repo’s workflow if you want packages stored directly on **`gh-pages`** with no releases.

**Summary:** GitHub Actions are **not** required; they **replace manual** package/index/upload steps. For a personal repo or rare releases, **Path A** is enough.

### Quick mental model

```
charts/my-new-chart/  (git)     ──►  helm package  ──►  my-new-chart-0.1.0.tgz
        │                                                    │
        │                                                    ├──► folder with ALL .tgz
        │                                                    │         │
        └────────────────────────────────────────────────────┘         ▼
                                                              helm repo index --url …
                                                                        │
                                                                        ▼
                                                              index.yaml + *.tgz
                                                                        │
                                                                        ▼
                                                              upload to HTTPS host
                                                                        │
                                                                        ▼
                                                              helm repo add / helm install
```

---

## Prerequisites

| Requirement | Why |
|---------------|-----|
| **Helm CLI** | `helm package`, `helm repo index`, `helm repo add` |
| **`helm env`** | Shows **`HELM_DATA_HOME`** (Helm’s global `starters/`, plugins), cache, and repo paths — do not assume fixed `~/.helm` locations. See [starters/webapp-starter/README.md](../starters/webapp-starter/README.md#helm-environment--helm-env-important). |
| **SemVer 2** in `Chart.yaml` (`version:`) | Required for chart versions and repo indexing |
| **Somewhere to host static files** | Any HTTPS server, object storage, or Git host with Pages |

---

## End-to-end workflow (classic HTTP repo)

### 1. Author and version your chart

- Each chart lives in a directory with `Chart.yaml`, `values.yaml`, and a `templates/` folder.
- Bump **`version`** (and optionally **`appVersion`**) in `Chart.yaml` when you release.

### 2. Package the chart

From the directory that **contains** your chart folder (not inside the chart):

```bash
helm package path/to/my-chart
```

This produces `my-chart-<version>.tgz`.

### 3. Build the repository index

Put all `.tgz` files in a folder (e.g. `charts/` or a release bucket path), then:

```bash
helm repo index ./charts --url https://your-domain.example.com/charts
```

- **`--url`** must be the **public base URL** where `index.yaml` and the `.tgz` files will be reachable.
- **`helm repo index` writes `index.yaml` inside the same directory you pass** (next to the `.tgz` files). After a successful run you will see **`index.yaml`** there even if the command prints nothing — that is expected.

**Git and that folder:** The directory you use for packaging + indexing (e.g. `publish/`, `publish-charts-dir/`, `site/`) is **build output** (`index.yaml` + `*.tgz`). On **`main`**, keep it **out of git** (see **`.gitignore`** in this repo) unless you deliberately version packages. If you already committed that folder, remove it from tracking with `git rm -r --cached <dir>` and keep the directory gitignored.

**CI vs local:** With **this repo’s [GitHub Action](../.github/workflows/publish-helm.yml)**, Helm runs **only in the runner**: it creates a temporary **`site/`** directory, then deploys **`index.yaml` + `*.tgz`** to the **`gh-pages`** branch. Nothing is required on **`main`** except chart **source** under **`charts/`**. If you publish **manually** (no CI), you build the same files locally in a ignored folder and upload them to your host yourself.

**Adding charts later:** `helm repo index` rebuilds the index from what it finds on disk. For an existing remote repo you can use **`helm repo index --merge`** to append without replacing everything—see `helm repo index --help`.

### 4. Upload artifacts

Upload **both**:

- `index.yaml`
- Every `*.tgz` (and `*.tgz.prov` if you use provenance)

to your host so URLs in `index.yaml` resolve.

### 5. Verify from a clean client

```bash
helm repo add myrepo https://your-domain.example.com/charts
helm repo update
helm search repo myrepo/
helm install myrelease myrepo/my-chart --version x.y.z
```

If `helm repo add` fails, Helm could not fetch a valid **`index.yaml`** (wrong URL, auth, TLS, or missing file).

---

## What must be true on the server

- **`GET /.../index.yaml`** returns YAML; ideally content type `text/yaml` or `text/x-yaml`.
- **Chart package URLs** in `index.yaml` must be **HTTPS GET**-able (unless you use insecure flags—not recommended).
- **Optional:** HTTP basic auth—supported via `helm repo add --username ... --password ...`.
- **Self-signed TLS:** `helm repo add --insecure-skip-tls-verify` (use proper CAs in production).

Official reference: [The Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/).

---

## Common hosting options

| Option | Good for |
|--------|----------|
| **GitHub Pages** | Free HTTPS static hosting; often paired with **Chart Releaser** automation |
| **Cloud storage** (GCS, S3, Azure Blob) | Public buckets behind HTTPS URLs |
| **ChartMuseum** | Dedicated chart server with various backends |
| **GitLab / Artifactory / Cloudsmith** | Enterprise registry features |
| **Any web server / CDN** | Full control; serve `index.yaml` + `.tgz` from a directory |

### GitHub Pages + automation (popular)

Typical pattern:

- Chart **source** on the default branch (e.g. `main`).
- **Packaged charts + `index.yaml`** on `gh-pages` or a `docs/` folder, served at `https://<user>.github.io/<repo>/`.
- Use **[helm/chart-releaser-action](https://github.com/helm/chart-releaser-action)** to tag releases, package charts, update `index.yaml`, and push to the Pages branch—reduces manual steps.

**This repo:** see [Path B — GitHub Actions](#path-b--github-actions-automation) and [`.github/workflows/publish-helm.yml`](../.github/workflows/publish-helm.yml) for the on-push workflow (lint → package → index → `gh-pages`).

### What GitHub Pages and `gh-pages` are

**GitHub Pages** is **free static website hosting** for repositories on GitHub. GitHub serves files over **HTTPS** from a location you choose in the repo **Settings** — there is **no application server**; only **static files** (HTML, YAML, images, archives, etc.). That is enough for a **Helm chart repository**, because clients only need to **GET** `index.yaml` and `*.tgz` by URL — the same model as in the [official chart repository guide](https://helm.sh/docs/topics/chart_repository/).

**Where the files live in Git:**

| Source | Meaning |
|--------|--------|
| **A branch** (often named **`gh-pages`**) | A branch whose **root** is the site root. For example, `index.yaml` at the branch root is served as `https://<owner>.github.io/<repo>/index.yaml`. |
| **`/docs` on `main`** | The `docs/` folder on your default branch can be the site (alternative to a separate branch). |
| **GitHub Actions** | A workflow can **publish** a build output (e.g. `site/`) to Pages without you committing those files to `main` — Pages can be configured to deploy from **Actions**. |

The name **`gh-pages`** is **convention**: many projects use a dedicated branch so **`main`** holds **source** (your Helm chart directories) while **`gh-pages`** holds **only** what is **published** (`index.yaml` + chart packages). That keeps packaging noise off `main`. This repo’s workflow pushes the built **`site/`** contents to the **`gh-pages`** branch so they appear at your **project Pages URL**.

**Your public URL (project site):**

`https://<github-username-or-org>.github.io/<repository-name>/`

That is the **base URL** you pass to **`helm repo index --url`** (usually with a **trailing slash**). Users add the repo with:

`helm repo add <alias> https://<owner>.github.io/<repo>/`

**Useful details:**

- **HTTPS** is standard; enable **Enforce HTTPS** in Pages settings when available.
- **Custom domains** are supported (CNAME / DNS); if you use one, set **`HELM_PAGES_BASE_URL`** in this repo’s Action or adjust **`--url`** accordingly so `index.yaml` lists correct download links.
- **Private repos:** GitHub Pages for private repositories may require a **paid GitHub** plan — check [GitHub Pages documentation](https://docs.github.com/en/pages) for current rules.
- **Limits:** bandwidth and file size limits apply; for typical team Helm repos this is usually fine.

### How `index.yaml` relates to GitHub Pages

**`index.yaml` is not special to Pages** — it is the **standard Helm chart repository index** ([Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/)). **GitHub Pages is only the static host** that makes that file (and the chart archives) reachable at fixed HTTPS URLs.

**What happens:**

1. **`helm repo add myrepo https://<owner>.github.io/<repo>/`** — the Helm client downloads **`index.yaml`** from **`https://<owner>.github.io/<repo>/index.yaml`** (that is the “repository URL” you configure).
2. **`index.yaml` lists charts** — for each chart version it stores metadata and one or more **`urls`** pointing to the **`*.tgz`** files (e.g. `https://<owner>.github.io/<repo>/example-0.1.0.tgz`).
3. **`helm install` / `helm pull`** — Helm uses those **`urls`** to download the package. Those links must **work in the browser or curl** (same as any static file on Pages).

So the relationship is: **Pages serves the files**; **`index.yaml` is the catalog** that tells Helm **what exists** and **where to download it**. You generate **`index.yaml`** with **`helm repo index ... --url <same-base-as-pages>`** so the **`urls`** inside it match where **`index.yaml`** and the **`.tgz`** files are actually hosted (typically the **root of your Pages site**, e.g. the **`gh-pages`** branch root).

**If `--url` is wrong:** `index.yaml` may still upload to Pages, but **`urls`** inside it point at the wrong host or path → **`helm install` fails** when fetching the `.tgz`.

---

## Checklist

**One-time setup**

- [ ] Choose **HTTP classic repo** vs **OCI registry** (see Helm docs for OCI if you prefer one registry for everything).
- [ ] Choose hosting (Pages, bucket, ChartMuseum, etc.) and get a **stable HTTPS base URL**.
- [ ] Ensure DNS/TLS and permissions (public read or credentials for `helm repo add`).
- [ ] If using **this repo’s GitHub Action**: enable **Pages** on branch **`gh-pages`**; optional repo variable **`HELM_PAGES_BASE_URL`** for a custom Pages domain (trailing slash).

**First time you add a new chart directory** (e.g. `charts/new-app/`)

- [ ] Commit the chart source; then **package + index + upload** — git alone does not update the Helm repo (see [Adding a chart](#adding-a-chart) above).

**Each chart release**

- [ ] Update **`version`** in `Chart.yaml` (SemVer 2).
- [ ] Run **`helm package`**; collect **all** `.tgz` you publish (including every chart in the repo, or use **`--merge`**) in the publish directory.
- [ ] Run **`helm repo index`** (with correct **`--url`**) or **`--merge`** as appropriate.
- [ ] Upload **`index.yaml`** and **all** relevant **`.tgz`** files.
- [ ] Tell consumers to **`helm repo update`** before installing new versions.

**Optional hardening**

- [ ] Sign charts and ship **`.prov` files** ([Helm provenance](https://helm.sh/docs/topics/provenance/)).
- [ ] Pin versions in CI/CD; avoid `:latest`-style ambiguity for chart versions.

---

## Quick reference commands

```bash
# Package (example chart in this repo)
helm package ./charts/example

# Create or refresh index (set URL to your real repo base)
helm repo index ./publish-dir --url https://example.com/helm

# Consumer
helm repo add myrepo https://example.com/helm
helm repo update
helm install rel myrepo/my-chart --version 1.2.3
```

### Before you publish — quick local checks

- **`helm lint charts/<chart>`** — catches common chart issues before you package.
- **`helm template release-name charts/<chart>`** — renders YAML locally without a cluster (sanity-check templates).
- **`helm package charts/<chart> --destination ./publish`** — writes the `.tgz` straight into `./publish` so you do not scatter archives in the repo root.
- After **`helm repo index ./publish --url …`**, **`index.yaml` appears inside `./publish`** — keep that whole directory **gitignored** on `main` unless you intentionally commit packages (see [§3 Build the repository index](#3-build-the-repository-index) above).
- **`--url` for `helm repo index`** must be the **exact HTTPS base** where **`index.yaml` and the `.tgz` files will live** (same path the browser would use). Wrong URL → broken install links for others.

---

## Further reading

- [docs/02-publish-helm-workflow.md](02-publish-helm-workflow.md) — step-by-step explanation of `.github/workflows/publish-helm.yml` (actions, variables, permissions)
- [docs/05-publish-helm-oci-workflow.md](05-publish-helm-oci-workflow.md) — optional `.github/workflows/publish-helm-oci.yml` (Docker Hub **`helm push`** from Actions)
- [docs/06-migrate-to-oci.md](06-migrate-to-oci.md) — migration plan from classic **`index.yaml`** repo to OCI
- [docs/07-artifact-hub.md](07-artifact-hub.md) — Artifact Hub: catalog versus hosting, and how a repository is registered
- [starters/README.md](../starters/README.md) — chart starters vs **`charts/`** in this repo
- [docs/08-microservices-helm-standardization.md](08-microservices-helm-standardization.md) — design note: standardize microservice charts with a few Helm starters
- [The Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/) — official structure, `index.yaml`, `helm repo index`
- [Use OCI-based registries](https://helm.sh/docs/topics/registries/) — publishing charts as OCI artifacts
- [docs/04-helm-oci.md](04-helm-oci.md) — Helm + OCI; Docker Hub **`helm push`** uses **`oci://docker.io/<username>`** only (see doc)
- [Chart Releaser](https://github.com/helm/chart-releaser) — CLI used by GitHub Actions for GitHub Pages repos
