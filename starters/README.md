# Starters

These directories are **templates** to copy from or pass to **`helm create -p <path>`**. They are **not** application charts and are **not** packaged by the GitHub Action (that workflow only processes **`charts/*/`**).

**Security:** Starters set **seccomp**, **drop capabilities**, **no privilege escalation**, and **no SA token automount** by default (good baseline vs many **Kyverno** / **Pod Security** checks). **webapp-starter** also has optional **NetworkPolicy** and **PDB**. **Cluster-level** policy (Kyverno `ClusterPolicy`, namespace **PSS** labels) is separate — see [webapp-starter README](webapp-starter/README.md#9-security-defaults-kyverno-and-pod-security-standards).

**Istio:** Both starters support optional **`istio.enabled`** (sidecar injection annotation, **`istio.io/rev`**, extra proxy annotations). See [webapp-starter §10](webapp-starter/README.md#10-istio-service-mesh-optional).

| Starter | Purpose |
|---------|---------|
| [basic-starter](basic-starter/README.md) | Minimal: Deployment, Service, optional ConfigMap & Secret |
| [webapp-starter](webapp-starter/README.md) | Fuller web app: Ingress, Gateway API HTTPRoute, optional External Secrets, PVC, HPA, etc. |

**Helper names:** starter templates use the placeholder **`<CHARTNAME>`** (e.g. `include "<CHARTNAME>.fullname"`). **`helm create`** replaces it with the new chart's name, so each chart gets unique helper names (Helm template names are global across a parent chart and its subcharts). If you copy a starter with **`cp -r`** instead, replace the placeholder yourself:

```bash
cp -r starters/webapp-starter charts/my-app
grep -rl '<CHARTNAME>' charts/my-app | xargs sed -i 's/<CHARTNAME>/my-app/g'
# edit charts/my-app/Chart.yaml and values.yaml
```

**Recommended — generate with Helm (and CI-friendly):** from the **repository root**, `helm create` with an **absolute path** to the starter avoids copying into `HELM_DATA_HOME`:

```bash
helm create my-app -p "$PWD/starters/webapp-starter"
```

There is also **[`scripts/new-chart-from-starter.sh`](../scripts/new-chart-from-starter.sh)** — same idea, defaults to **`charts/<name>`** and **`webapp-starter`**. Call it from **GitLab CI**, **GitHub Actions**, or locally after checkout; ensure **`helm`** is on `PATH` in the job image.

See [webapp-starter README](webapp-starter/README.md#helm-environment--helm-env-important) for **`helm env`** / **`HELM_DATA_HOME`** when installing a starter into Helm’s global **`starters/`** directory for **`helm create -p webapp-starter`** **by short name**.
