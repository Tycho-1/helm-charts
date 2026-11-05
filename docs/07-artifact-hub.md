# 07. Artifact Hub

Artifact Hub is a catalog for Helm charts. This document describes how it differs from hosting charts on GitHub Pages or another HTTP or OCI backend, and how a chart repository is registered there.

Official documentation: [Artifact Hub docs](https://artifacthub.io/docs/), [Helm charts repositories](https://artifacthub.io/docs/topics/repositories/helm-charts/), [FAQ](https://artifacthub.io/docs/topics/faq/).

---

## What Artifact Hub is (summary)

**Artifact Hub** is a **public discovery and metadata service** for cloud-native artifacts. It is a **[CNCF](https://www.cncf.io/)** project. For Helm, it acts as a **catalog**: users **search and browse** charts, read descriptions, see versions, and follow links to **install** — similar in spirit to how a package search site works for Linux distributions.

**Important:** Artifact Hub **does not replace** your chart **hosting**. Your packaged charts (`.tgz`) and **`index.yaml`** must still be served from **somewhere** reachable over the network — for example:

- A **classic HTTP Helm repo** (e.g. **GitHub Pages**, S3, any static server) with `index.yaml` + `.tgz`, as in the [Helm Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/), **or**
- **OCI** registries (`oci://...`) with Helm chart artifacts.

Artifact Hub **indexes** what you already publish: you **register the repository URL** in Artifact Hub’s UI (after signing in). It periodically **pulls** your `index.yaml` and chart metadata and displays them on [artifacthub.io](https://artifacthub.io/).

---

## Artifact Hub and GitHub Pages

| | **GitHub Pages** | **Artifact Hub** |
|---|------------------|------------------|
| **Role** | **Hosts** static files over HTTPS (`index.yaml`, `.tgz`) | **Indexes** metadata from a repo URL you already host elsewhere |
| **Helm `helm repo add`** | Uses the **Pages URL** as the chart repo base | **Not** used as `helm repo add` — users still add **your** repo URL (Pages, OCI, etc.) |
| **Required** | **Only Pages** (or another host) is required to serve a classic repo | **Optional** — improves **discoverability** and **presentation** |

**GitHub Pages** hosts the files. **Artifact Hub** indexes those files and adds search and metadata. It is not a second copy of the chart repository.

---

## Benefits of listing charts on Artifact Hub

- **Discoverability** — People search by name, keyword, and category without knowing your GitHub org or raw URL.
- **Consistent UI** — Version history, default values, readme rendering, install snippets, links to source.
- **Security and quality signals** — Artifact Hub integrates **security reports** and related checks where applicable (see [official docs](https://artifacthub.io/docs/) for current features).
- **Verified publisher / ownership** — You can add **`artifacthub-repo.yml`** next to **`index.yaml`** (same HTTP path) to support [verified publisher](https://artifacthub.io/docs/topics/repositories/#verified-publisher) and related flows — see [repository metadata](https://github.com/artifacthub/hub/blob/master/docs/metadata/artifacthub-repo.yml).
- **Richer chart metadata** — Optional **[Artifact Hub annotations in `Chart.yaml`](https://artifacthub.io/docs/helm_annotations/)** (links, license, screenshots, etc.).
- **Broader ecosystem** — Same hub lists other artifact types (operators, plugins, etc.), so users find Helm charts in one familiar place.

Nothing stops you from using **only** GitHub Pages and sharing the URL manually; Artifact Hub is an **extra channel** for distribution and discovery.

---

## Registering a repository

1. **Host your Helm repository** first (same as in this repo’s README): e.g. **`https://<owner>.github.io/<repo>/`** with valid **`index.yaml`** and **`.tgz`** files, or an **OCI** layout per [Artifact Hub’s OCI notes](https://artifacthub.io/docs/topics/repositories/helm-charts/).
2. **Create an account** on [artifacthub.io](https://artifacthub.io/) and sign in.
3. Open the **control panel** (user menu) and **add a repository** under your user or an [organization](https://artifacthub.io/docs/topics/repositories/).
4. Enter the **repository URL** — for a classic HTTP repo, the **same base URL** you use with **`helm repo add`** (where **`index.yaml`** is served).
5. Artifact Hub **reprocesses** repositories on a schedule (on the order of **tens of minutes**; see [FAQ](https://artifacthub.io/docs/topics/faq/) for current behavior). New chart versions you publish to your **existing** host appear in the index after the next successful fetch.

**OCI Helm charts:** The URL format is different (`oci://registry/namespace/chart-name`). There are **OCI-specific** constraints (e.g. listing multiple charts from one OCI namespace differs from classic `index.yaml` repos); read [Helm charts on Artifact Hub — OCI support](https://artifacthub.io/docs/topics/repositories/helm-charts/).

---

## Optional: `artifacthub-repo.yml` and annotations

- **`artifacthub-repo.yml`** — Placed at the **same level** as **`index.yaml`** on your HTTP chart repository and **served** by the same static host. Used for features like **verified publisher** and **ownership claim**. Template: [artifacthub-repo.yml](https://github.com/artifacthub/hub/blob/master/docs/metadata/artifacthub-repo.yml).
- **`Chart.yaml` annotations** — [Artifact Hub Helm annotations](https://artifacthub.io/docs/helm_annotations/) improve the listing (links, categories, etc.). Per-version notes use `artifacthub.io/changes`; see [03-chart-changelog.md](03-chart-changelog.md).

---

## Quick comparison workflow

```text
Your chart source (git main)
        │
        ▼
  CI: helm package + helm repo index
        │
        ▼
  Hosted repo (e.g. GitHub Pages gh-pages branch)
  URL: https://owner.github.io/repo/  ← helm repo add uses this
        │
        ├──────────────────────────────► Users install directly from here
        │
        └──────────────────────────────► Register same URL in Artifact Hub
                                         (discovery + metadata; not a second host)
```

---

## Crossplane packages, OCI, and Artifact Hub

**Crossplane “packages”** in the native sense (**xpkgs** — Providers, Configurations, Functions, etc.) are published as **OCI images** using Crossplane’s tooling, not Helm’s:

| | **Helm chart (OCI or HTTP)** | **Crossplane xpkg** |
|---|------------------------------|----------------------|
| **Build / push** | **`helm package`**, **`helm push oci://...`** | **`crossplane xpkg build`**, **`crossplane xpkg push`** |
| **What’s inside** | Helm chart (`Chart.yaml`, `templates/`, …) for **`helm install`** | **`crossplane.yaml`**, CRDs, package layers — see [Crossplane packages](https://docs.crossplane.io/latest/packages/) |
| **Install** | **`helm install … oci://…`** or classic repo | **`Configuration` / `Provider` / `Function`** objects with **`spec.package`** pointing at an OCI ref (Crossplane pulls the image) |

**Same underlying technology:** both use an **OCI registry** (GHCR, Docker Hub, ECR, `xpkg.upbound.io`, …) — **same kind of server**, **different artifact layout and CLI**. You do **not** create an xpkg with **`helm push`**, or a Helm chart with **`crossplane xpkg push`**.

**Artifact Hub:**

- What you usually see for **“Crossplane”** on [Artifact Hub](https://artifacthub.io/packages/search?ts_query_web=crossplane) is the **Helm chart** that **installs the Crossplane controller** (standard **Helm** repository type). That is **not** the same as listing every **provider/configuration xpkg**.
- **Native xpkgs** may be listed if Artifact Hub supports the right **repository kind** for your OCI source — [supported kinds](https://artifacthub.io/docs/topics/repositories/) change over time. Check the current **[Artifact Hub docs](https://artifacthub.io/docs/)** when registering.
- Many teams publish xpkgs to a **registry** and document **`spec.package`** (e.g. `xpkg.upbound.io/...`) in READMEs or vendor marketplaces — **independent** of Artifact Hub unless you also register there.

**Short answer:** **OCI** is shared transport; **Helm charts** and **Crossplane xpkgs** are **different package types**. Artifact Hub is a natural fit for **Helm** discovery; for **xpkgs**, follow Crossplane and Artifact Hub docs for **hosting** and **listing**.

---

## Further reading

- [Artifact Hub — Helm chart repositories](https://artifacthub.io/docs/topics/repositories/helm-charts/)
- [Artifact Hub — Repositories (overview)](https://artifacthub.io/docs/topics/repositories/)
- [Helm — Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/) (hosting the actual repo)
- [docs/04-helm-oci.md](04-helm-oci.md) — OCI-based Helm publishing (also supported by Artifact Hub with OCI-specific setup)
- [Crossplane — Packages](https://docs.crossplane.io/latest/packages/) — xpkg build/push (OCI, not Helm)
