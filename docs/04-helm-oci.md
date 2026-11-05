# 04. Helm OCI registries

Helm can store charts in an **OCI registry** (the same kind of registry used for container images: Docker Hub, GHCR, ECR, Harbor, etc.). The chart is pushed as an **OCI artifact** instead of being listed in an HTTP `index.yaml`.

Official reference: [Use OCI-based registries](https://helm.sh/docs/topics/registries/).

---

## Summary

| Topic | What it means |
|--------|----------------|
| **OCI** | Open Container Initiative layout; registries store **blobs** and **manifests** (images *and*, with Helm 3, **charts**). |
| **Classic repo** | HTTP URL + `index.yaml` + `.tgz` files; `helm repo add` / `helm repo update`. |
| **OCI workflow** | `helm push` / `helm pull` / `helm install oci://...` — **no** `index.yaml` on the registry for discovery (you rely on tags and registry UI/API). |
| **Remove** | **Not** via Helm — delete **tags** or the **repository** in the registry (UI or tools like **`crane`**); see [Removing published charts](#removing-published-charts-from-the-registry). |

Helm **3.8+** treats OCI as the standard way to push/pull charts to registries that support OCI artifacts.

---

## Main points

1. **One registry for images and charts** — Same credentials, scanning, and network path as your containers (where your registry supports chart artifacts).

2. **No `helm repo index`** — Packaging is still `helm package`; publishing is **`helm push`** to an `oci://` URL, not uploading `index.yaml` + tarballs to static hosting.

3. **Versioning** — Chart version is typically reflected in the **OCI tag** (e.g. `0.2.0`). Consumers pin with **`--version`** on `helm install` / `helm upgrade`.

4. **Authentication** — Use **`helm registry login`** (or your usual `docker login` to the same registry, depending on setup) before push/pull to private registries.

5. **Discovery** — Unlike a classic repo with a single `index.yaml`, discovery is **registry-centric** (tags, catalog APIs, UI). Some teams mirror metadata elsewhere or use tools that list OCI tags.

6. **Chart dependencies** — Subcharts can reference OCI URLs in `Chart.yaml` (`dependencies` with `repository: oci://...`); see the Helm docs for the exact schema your Helm version expects.

---

## Prerequisites

- Helm **3.8+** (OCI support matured across 3.x; use a recent 3.x for fewer edge cases).
- A registry that **supports OCI artifacts** for Helm charts (most major cloud and self-hosted registries do; confirm for yours).
- For private registries: credentials configured via **`helm registry login <host>`**.

---

## Which registry? How `helm registry login` works

Docs often show **`registry.example.com`** — that is only a **placeholder**. You replace it with the **hostname of the OCI registry you actually use** (no `https://`, no path — just the host).

**Pick the registry where you will `helm push` your chart** — often the **same** place you already push container images:

| Registry | Typical host for `helm registry login` |
|----------|----------------------------------------|
| **GitHub Container Registry** | `ghcr.io` |
| **Docker Hub** | `docker.io` (or omit and use defaults for Docker CLI) |
| **GitLab Container Registry** | `registry.gitlab.com` |
| **Amazon ECR** | `123456789012.dkr.ecr.<region>.amazonaws.com` |
| **Azure Container Registry** | `myregistry.azurecr.io` |
| **Google Artifact Registry** | `<location>-docker.pkg.dev` or GCR host per GCP docs |
| **Harbor / self-hosted** | Your Harbor URL host, e.g. `harbor.mycompany.com` |

### Docker Hub: hostname vs profile URL vs username

The **hostname** is **`docker.io`** — the registry’s API host. It is **not** your browser profile URL (e.g. `https://hub.docker.com/repositories/youruser`); that site is only for managing repos in the UI.

| | Example |
|---|--------|
| **Hostname** (`helm registry login …`) | **`docker.io`** |
| **Username** (`-u` or prompt) | Your **Docker ID** (e.g. `tycho1`) — the account namespace, not a full URL |
| **Password** | Account password or, preferably, a **[Docker Hub access token](https://docs.docker.com/security/for-developers/access-tokens/)** |

```bash
helm registry login docker.io -u tycho1
# password: paste token or password
```

**Login** always uses the host **`docker.io`** only (see above). **Push** uses **`oci://docker.io/<namespace>`** only — Helm adds the chart **`name`** as the repository segment (see below). **Install** references the full repo, e.g. **`oci://docker.io/tycho1/example`**.

#### `helm push` on Docker Hub — which path?

Use **`docker.io`** as the registry host in the `oci://` URL — **not** `https://hub.docker.com/...`, and typically **not** `registry.docker.io` in the `oci://` string (Helm and Docker expect **`docker.io`**).

**Important (Helm + Docker Hub):** Helm **appends the chart `name`** from **`Chart.yaml`** to the path you pass. Docker Hub only allows a repository name of **`namespace/repository`** (one slash). If you also put the chart name in the **`oci://`** URL, you get **three** segments, e.g. **`tycho1/example/example`** (invalid). That mistake often returns **401** / **`insufficient_scope`** — it can look like bad credentials even when login is fine.

| What you pass to `helm push` | Chart `name:` in `Chart.yaml` | Resulting Docker Hub repo |
|------------------------------|-------------------------------|---------------------------|
| **`oci://docker.io/tycho1`** | `example` | **`tycho1/example`** (valid) |
| **`oci://docker.io/tycho1/example`** | `example` | **`tycho1/example/example`** (invalid on Hub) |

So for Docker Hub, use **only your user/org** after **`docker.io/`**:

```bash
helm push example-0.1.0.tgz oci://docker.io/tycho1
helm pull oci://docker.io/tycho1/example --version 0.1.0
helm install myrelease oci://docker.io/tycho1/example --version 0.1.0   # needs a cluster
```

That publishes to repository **`tycho1/example`**. **Do not** use `oci://docker.io/tycho1/example` for **`helm push`** unless you know your Helm version behaves differently (install/pull **do** use the full path including the chart name).

Generic non–Docker Hub docs often show `oci://registry.example.com/myteam/helm` — other registries allow deeper paths; **Docker Hub does not**.

**Do I create the repo on the website first?** Often **no** — the first successful **`helm push`** can **create** it. If the push is rejected, create an **empty** repository in the [Docker Hub UI](https://hub.docker.com/) with the expected name (e.g. **`example`** under user **`tycho1`**), then push again.

**Path depth:** On Docker Hub the **stored** repository is always **`namespace/repository`** — **one** slash. With **`helm push`**, pass **`oci://docker.io/<namespace>`** so the effective name stays two segments. Do **not** add extra URL segments that mirror the chart name (that duplicates it). Deeper paths like `oci://docker.io/tiho/helm/test-app` are for other registries; on Hub they tend to produce invalid **three-segment** names when Helm also appends **`Chart.yaml` `name`**.

---

**Login (any registry):**

```bash
helm registry login <hostname>
# Prompts for username + password (or token)
```

**Non-interactive (CI or scripts):**

```bash
echo "$TOKEN" | helm registry login ghcr.io -u USERNAME --password-stdin
```

Use a **personal access token** or **robot account token** as the password where your registry requires it (e.g. GitHub **PAT** with `write:packages` for GHCR).

**`docker login`:** Many setups also work if you run **`docker login <same-host>`** — Helm can reuse Docker’s credential store depending on configuration. If in doubt, use **`helm registry login`**.

**`helm push` returns 401 and you already use `oci://docker.io/<username>` only:**  

**Note:** **`helm registry login` / `docker login` reporting success** only means credentials were accepted for **login**. **`helm push`** uses separate requests; you can still get **401** on push if Helm’s config does not supply auth for those calls (see below). Password and PAT can both show “Login Succeeded”; prefer a **PAT** for automation and 2FA accounts.

1. **Use Helm’s login, not only Docker’s** — **`docker login`** updates **`~/.docker/config.json`**; **`helm push`** reads **`HELM_REGISTRY_CONFIG`** (see **`helm env`**). Run **`helm registry login docker.io -u <user>`** with your **PAT** as the password.

2. **Always log in with `docker.io`**, not **`registry-1.docker.io`**. Docker Hub’s API uses **`registry-1.docker.io`** in URLs, but credentials must be stored under the key Docker Hub expects (see [Helm issue #30929](https://github.com/helm/helm/issues/30929)).  
   ```bash
   helm registry logout docker.io
   echo "$DOCKERHUB_PAT" | helm registry login docker.io -u YOUR_DOCKER_ID --password-stdin
   ```

3. **Helm v3.18.0** had a bug where **`helm registry login`** wrote a config key that broke Docker Hub (**401** on push/pull). **Upgrade to Helm v3.18.2 or newer** (`helm version --short`). See [Helm 3.18.2 milestone](https://github.com/helm/helm/issues/30929).

4. **Manual workaround** (if you cannot upgrade yet): after **`helm registry login`**, copy the auth entry so **`https://index.docker.io/v1/`** exists in **`~/.config/helm/registry/config.json`** with the **same** `auth` value as for **`registry-1.docker.io`** (or run the **`sed`** fix from the [issue](https://github.com/helm/helm/issues/30929)). Alternatively merge credentials from **`docker login`** into that file under **`https://index.docker.io/v1/`** (base64 of `username:token`).

**See your Helm config paths:** **`helm env`** (e.g. **`HELM_REGISTRY_CONFIG`**) shows where registry auth is stored.

---

## Example workflow (local chart)

Assume a packaged chart `myapp-1.0.0.tgz` and a registry host `registry.example.com` (**replace with your real registry hostname**).

### 1. Package (unchanged from classic repos)

```bash
helm package ./charts/myapp
# → myapp-1.0.0.tgz
```

### 2. Log in to the registry

```bash
helm registry login registry.example.com
# Or non-interactive: echo "$TOKEN" | helm registry login registry.example.com --username "$USER" --password-stdin
```

### 3. Push the chart

```bash
helm push myapp-1.0.0.tgz oci://registry.example.com/myteam/helm
```

The **repository path** after `oci://` (`myteam/helm/...`) is your naming convention; the chart **name** and **version** come from `Chart.yaml` and the `.tgz` filename.

### 4. Install from OCI

```bash
helm install myrelease oci://registry.example.com/myteam/helm/myapp --version 1.0.0
```

Adjust the **chart path** (`.../myapp`) to match how your registry lays out the artifact (Helm resolves the chart name from the pushed artifact).

### 5. Pull without installing

```bash
helm pull oci://registry.example.com/myteam/helm/myapp --version 1.0.0
```

---

## Test locally (before CI)

Use these to validate **`helm push`** / **`helm pull`** on your machine. Requires Helm **3.8+**; for **Docker Hub**, use **3.18.2+** (see the **401 troubleshooting** list under [Docker Hub](#docker-hub-hostname-vs-profile-url-vs-username) above).

### Docker Hub (matches this repo’s CI workflow)

Replace **`YOUR_DOCKER_ID`** and set a **[Docker Hub access token](https://docs.docker.com/security/for-developers/access-tokens/)** in the environment (not your account password if you use 2FA).

```bash
cd charts/example   # or any chart under charts/*/
helm package .

helm registry logout docker.io 2>/dev/null || true
echo "$DOCKERHUB_PAT" | helm registry login docker.io -u YOUR_DOCKER_ID --password-stdin

# Push: namespace only — Helm adds the chart name from Chart.yaml
helm push example-0.1.0.tgz oci://docker.io/YOUR_DOCKER_ID

helm pull oci://docker.io/YOUR_DOCKER_ID/example --version 0.1.0
# helm install test-release oci://docker.io/YOUR_DOCKER_ID/example --version 0.1.0
```

On [hub.docker.com](https://hub.docker.com) you should see repository **`YOUR_DOCKER_ID/example`** with tag **`0.1.0`**. Remove the tag or repo in the UI when you are done testing.

### Local registry (no Docker Hub account)

Exercises the **generic** path rules (`oci://host/prefix` on push; chart name in the URL on pull/install):

```bash
docker run -d -p 5000:5000 --name helm-registry registry:2
helm package charts/example
helm push example-0.1.0.tgz oci://localhost:5000/helm
helm pull oci://localhost:5000/helm/example --version 0.1.0
docker rm -f helm-registry
```

### GitHub Actions (manual run)

1. Add secrets **`DOCKERHUB_USERNAME`** and **`DOCKERHUB_TOKEN`** under **Settings → Secrets and variables → Actions**.
2. **Actions → Helm push OCI → Run workflow** → **Chart** = **`example`** (folder name under **`charts/`**).
3. Confirm the chart appears on Docker Hub.

For tag-based releases in a monorepo, use git tags like **`example-0.1.0`** (same **`name`** and **`version`** as in **`Chart.yaml`**). Tags such as **`v1.0.0`** do **not** trigger the OCI workflow.

**Convention:** Keep each chart’s **folder name** under **`charts/`** the same as **`name:`** in **`Chart.yaml`** (for example folder **`example`**, name **`example`**). The manual workflow input is the folder name. The git tag uses **`name`** and **`version`** from **`Chart.yaml`**. Packaging uses the chart name, not the folder name.

---

## Removing published charts from the registry

Helm has **no** command to delete a chart from a remote registry (nothing like `helm push` in reverse). A published OCI chart is a **tagged manifest** in the registry; you remove it with the **registry’s UI** or a **registry client** that can delete tags or repositories.

**What to delete**

- **One version** — delete the **tag** that matches the chart version (often the SemVer string, e.g. `0.1.0`).
- **Whole chart (all versions)** — delete the **repository** (or package) in the vendor UI, if your workflow allows it.

### Docker Hub

1. Open **[hub.docker.com](https://hub.docker.com)** → your namespace → the repository (e.g. **`tycho1/example`** after a correct **`helm push`**).
2. **Tags** — remove individual tags to drop specific chart versions.
3. **Settings** → **Delete repository** — removes the entire repository and all tags.

Use credentials that can manage that repository (owner or collaborator with delete rights).

### Other registries (short pointers)

| Registry | Typical approach |
|----------|------------------|
| **GHCR** | GitHub **Packages** UI for the container/package, or GitHub API / **`gh`** to delete package versions. |
| **ECR / ACR / Harbor** | Console or cloud CLI: delete **image**/**artifact** tags or the **repository** per vendor docs. |

### CLI: `crane` or `regctl` (optional)

You do **not** need any extra tool to remove charts if you are fine using the **registry website** (e.g. Docker Hub **Tags** / **Delete repository** above). **`crane`** and **`regctl`** are only for **terminal** or **automated** deletes.

If you already authenticate to the registry (`docker login`, `helm registry login`, or env-based auth), generic OCI tools often work for Helm charts too:

**[crane](https://github.com/google/go-containerregistry/tree/main/cmd/crane)** (delete one tag; chart version = tag):

```bash
crane delete docker.io/tycho1/example:0.1.0
```

Use the same **`registry/repo:tag`** reference you would use to pull that chart version.

**[regctl](https://github.com/regclient/regclient)** — `regctl tag delete …` / manifest operations (see `regctl --help` for your version).

**Caution:** Deleting a tag removes that version for everyone; anyone pinning **`helm install … --version`** to that tag will fail afterward. Coordinate with consumers before deleting production tags.

---

## Minimal comparison

| Action | Classic HTTP repo | OCI registry |
|--------|-------------------|----------------|
| Publish | `helm package` + `helm repo index` + upload `index.yaml` + `.tgz` | `helm package` + **`helm push`** to `oci://...` |
| Configure client | `helm repo add` + `helm repo update` | **`helm registry login`** (if private) |
| Install | `helm install rel myrepo/chart --version x.y.z` | **`helm install rel oci://registry/.../chart --version x.y.z`** |
| **Remove** | Remove `.tgz` from hosting, regenerate **`index.yaml`**, or stop serving the URL | **No Helm delete** — remove **tags** or **repository** in registry **UI** or CLI (**`crane`**, **`regctl`**, vendor tools) |

---

## GitHub Actions (automate `helm push`)

You can publish charts to an OCI registry from CI the same way you would locally: **`helm package`**, **`helm registry login`**, **`helm push oci://…`**.

This repo includes an **optional** workflow **[`.github/workflows/publish-helm-oci.yml`](../.github/workflows/publish-helm-oci.yml)** that pushes to **Docker Hub** when you **run it manually** or push a **per-chart** git tag **`name-version`** (same **`name`** and **`version`** as in that chart’s **`Chart.yaml`**, e.g. **`payments-api-2.0.0`**) so **only that chart** is **`helm push`**’d in a monorepo. Unrelated tags (e.g. **`v1.0.0`**) do **not** trigger it. Set secrets **`DOCKERHUB_USERNAME`** and **`DOCKERHUB_TOKEN`**. Full details: [docs/05-publish-helm-oci-workflow.md](05-publish-helm-oci-workflow.md). Local smoke test: [Test locally (before CI)](#test-locally-before-ci).

**Note:** That workflow is separate from **[`publish-helm.yml`](../.github/workflows/publish-helm.yml)** (GitHub Pages + HTTP repo). You can use **both** — classic **`index.yaml`** for `helm repo add` **and** OCI for `helm install oci://…`. Migrating off the classic repo: [docs/06-migrate-to-oci.md](06-migrate-to-oci.md).

---

## When to prefer OCI

- You already run an **OCI registry** and want **one** auth and promotion story for images and charts.
- You want **immutable tags** and registry-native **access control** and auditing.
- You do **not** want to operate static hosting + `index.yaml` (though automation can make classic repos easy too).

When **classic HTTP** still fits: public static hosting only, legacy `helm repo` workflows, or tools that expect `index.yaml` (some air-gapped mirrors are built around it).

---

## Crossplane xpkgs — also OCI, but not Helm charts

**Crossplane** distributes **Providers**, **Configurations**, and related **packages** as **OCI images** (**xpkg**), using **`crossplane xpkg build`** / **`crossplane xpkg push`** — not **`helm push`**. The **registry** is often the same technology (GHCR, ECR, …) as for Helm OCI charts, but the **artifact format and install path** are Crossplane-specific. See [Crossplane packages](https://docs.crossplane.io/latest/packages/). For **Artifact Hub** and Crossplane, see [docs/07-artifact-hub.md](07-artifact-hub.md#crossplane-packages-oci-and-artifact-hub).

---

## Further reading

- [Use OCI-based registries](https://helm.sh/docs/topics/registries/) — authoritative Helm behavior and flags
- [The Chart Repository Guide](https://helm.sh/docs/topics/chart_repository/) — HTTP `index.yaml` model (contrast)
- Registry vendor docs for **Helm OCI** support (GHCR, ECR, ACR, Harbor, etc.)
