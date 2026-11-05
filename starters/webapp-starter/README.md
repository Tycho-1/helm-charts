# webapp-starter

Opinionated starter chart based on **`helm create`** defaults, extended for typical web workloads (Service, Ingress or Gateway API HTTPRoute, ConfigMap, Secret, optional External Secrets Operator `ExternalSecret`, optional Istio injection annotations, PVC, HPA, ServiceAccount).

---

## When to use this

Use it as a **template**: copy from **`starters/webapp-starter`** into **`charts/<your-app>/`**, rename as needed, then adjust `values.yaml` for your image, ports, networking, and optional resources. You keep iterating under **`charts/`** (or publish from a Helm repo — see the [repository README](../../README.md)).

---

## Helm environment — `helm env` (important)

Helm stores **starters**, **plugins**, and other data under paths that follow the [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html) layout on Linux (and similar conventions on macOS). **Do not guess** `~/.helm` paths — use the CLI.

```bash
helm env              # print all Helm-related paths and settings
helm env HELM_DATA_HOME   # only the data directory (starters live under …/starters/)
```

**Typical meanings** (names match what `helm env` prints):

| Variable | Role |
|----------|------|
| **`HELM_DATA_HOME`** | Data directory: **`starters/`** (chart starters), **`plugins/`**, etc. |
| **`HELM_CONFIG_HOME`** | Config (e.g. repo list often referenced from here / registry config). |
| **`HELM_CACHE_HOME`** | Cache (e.g. chart tgz cache under `helm/`). |
| **`HELM_REPOSITORY_CACHE`** | Cached `index.yaml` files for `helm repo add`. |
| **`HELM_REPOSITORY_CONFIG`** | `repositories.yaml` — known chart repos. |

Paths can differ per user, OS, or if you set **`XDG_*`** or Helm’s overrides — **`helm env`** is the source of truth.

Official command reference: [helm env](https://helm.sh/docs/helm/helm_env/).

---

## 1. Create your chart from the starter

Helm supports several workflows. In **this git repo**, starters live under **`starters/`**; your real charts go under **`charts/`**. You **do not** have to install anything under `~/.local/share/helm` unless you want a **short name** for `helm create -p webapp-starter`.

### Where named starters live (official Helm layout)

If you use **`helm create <chart> -p <starter-name>`** with a **name** (not a path), Helm resolves the scaffold from:

**`$HELM_DATA_HOME/starters/<starter-name>`**

Check your machine:

```bash
helm env HELM_DATA_HOME
# Typical on Linux: ~/.local/share/helm
# Named starter path:   ~/.local/share/helm/starters/webapp-starter
```

So it is **`…/helm/starters/webapp-starter`**, **not** `~/.local/share/helm/webapp-starter` (there must be a **`starters`** directory in between).

**Install the starter for short names:**

```bash
ST="$(helm env HELM_DATA_HOME)/starters"
mkdir -p "$ST"
cp -r /path/to/this/repo/starters/webapp-starter "$ST/webapp-starter"
helm create myapp -p webapp-starter
```

That creates a new **`./myapp`** chart from the starter. Then adjust **`Chart.yaml`** / **`values.yaml`** as below.

### Option A — Copy into `charts/` in this repo (no `helm create`)

From the **repository root**:

```bash
cp -r starters/webapp-starter charts/<your-app-name>
```

That creates **`charts/<your-app-name>/`**, which is where published charts live in this repository. You must then replace the **`<CHARTNAME>`** placeholder (see **Helpers** below) — prefer **`scripts/new-chart-from-starter.sh <your-app-name>`**, which does it for you.

### Option B — `helm create` with an **absolute path** (no `~/.local` copy)

`--starter` may be a **path** to the scaffold. Nothing is copied into **`HELM_DATA_HOME/starters`**:

```bash
helm create myapp -p /absolute/path/to/helm-charts/starters/webapp-starter
```

Helm creates **`./myapp`** from that directory.

### After you have a new chart directory

Edit **`Chart.yaml`** (whether from Option A, B, or the named-starter flow):

| Field | Change to |
|--------|-----------|
| `name` | Your chart name (often matches the folder; use lowercase and hyphens). |
| `description` | Short text for humans. |
| `version` | Chart package version (SemVer); bump when you change the chart. |
| `appVersion` | Your application version string (informational). |

**Helpers:** Templates in the starter use the placeholder **`<CHARTNAME>`** as the helper prefix (e.g. **`include "<CHARTNAME>.fullname"`**). **`helm create`** (Option B, the named-starter flow, or **`scripts/new-chart-from-starter.sh`**) replaces it with your chart name, so every chart gets unique helper names. This matters because Helm template names are **global** across a parent chart and its subcharts — two charts sharing a prefix would overwrite each other's helpers. With **Option A** (`cp -r`), replace it yourself:

```bash
grep -rl '<CHARTNAME>' charts/<your-app-name> | xargs sed -i 's/<CHARTNAME>/<your-app-name>/g'
```

**Minimum next step:** edit **`values.yaml`**. Set `image.repository` and `image.tag`. `service.port` is the Service port; `service.containerPort` is what the process listens on. Probe defaults are HTTP GET `/` for the nginx stand-in — change the path or the probe type, or set a probe to `{}` to omit it. `httpGet.port` must match `service.portName`. Enabling the ConfigMap, Secret, or ExternalSecret spec adds a checksum annotation so that change rolls the Deployment. A secret rotated only in the external store does not.

---

## 2. Validate before installing

Run these from **`charts/<your-app-name>/`** (the chart directory):

```bash
helm lint .
helm template myrelease . --debug
```

Optional: render with a custom values file:

```bash
helm template myrelease . -f my-values.yaml
```

Fix any template errors before touching a cluster.

---

## 3. Install into a cluster

You need a Kubernetes cluster and `kubectl` context set.

**Install from the chart path** (development):

```bash
helm install myrelease ./charts/<your-app-name> --namespace myapp --create-namespace
```

**Install with overrides** (without editing files):

```bash
helm install myrelease ./charts/<your-app-name> \
  --set image.repository=myregistry/myapp \
  --set image.tag=1.2.3
```

**Install with a values file:**

```bash
helm install myrelease ./charts/<your-app-name> -f my-values.yaml
```

**Upgrade** after you change the chart or values:

```bash
helm upgrade myrelease ./charts/<your-app-name> -f my-values.yaml
```

**Uninstall:**

```bash
helm uninstall myrelease --namespace myapp
```

---

## 4. Networking: Ingress vs HTTPRoute

Do **not** enable both unless you know you need two entry paths (unusual). Pick one model for external traffic.

### Classic Ingress (`ingress.enabled: true`)

- Works with **IngressClass** (e.g. nginx, AWS ALB) and CRD `networking.k8s.io/v1` Ingress.
- Set **`ingress.hosts`**, **`ingress.className`**, and annotations your controller expects.
- **TLS:** use **`ingress.tls`** and point **`secretName`** at a **TLS Secret** in the same namespace (often created by cert-manager). That is separate from the chart’s **`secret`** block (application secrets).

### Gateway API (`httpRoute.enabled: true`)

- The cluster must have **Gateway API CRDs** and a **Gateway** (and controller) already installed.
- This chart only creates an **HTTPRoute**; you set **`httpRoute.parentRefs`** to attach to your **Gateway** (name, namespace, `sectionName` / port as required by your controller).
- If you **disable** Ingress and HTTPRoute, the app is only reachable **inside the cluster** via **Service** (ClusterIP) or **NodePort** / **LoadBalancer** depending on `service.type`.

---

## 5. ConfigMap and Secret (application config)

When **`configMap.enabled`** and/or **`secret.enabled`** are true, the Deployment uses **`envFrom`**: each key in **`configMap.data`** and **`secret.stringData`** becomes an **environment variable** with the **same name** (uppercase keys are common for secrets).

Example:

```yaml
configMap:
  enabled: true
  data:
    LOG_LEVEL: "info"

secret:
  enabled: true
  stringData:
    API_KEY: "replace-in-production"
```

Secrets in git are **unsafe**; for production use **Sealed Secrets**, **External Secrets**, **SOPS**, or inject values from CI with `--set-file` / `--set` and never commit real values.

### External Secrets Operator (`externalSecret.enabled`)

When **`externalSecret.enabled: true`**, the chart creates an **`ExternalSecret`** that syncs remote credentials into a normal Kubernetes **`Secret`**, and the Deployment **`envFrom`** references that Secret (same pattern as **`secret.enabled`**).

- Install [External Secrets Operator](https://external-secrets.io/latest/introduction/getting-started/) and configure a **`SecretStore`** or **`ClusterSecretStore`** (Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, etc.).
- Set **`externalSecret.secretStoreRef.name`** (and **`kind`**: **`SecretStore`** or **`ClusterSecretStore`**) to match your store.
- Define **`externalSecret.data`** and/or **`externalSecret.dataFrom`** per the [ExternalSecret API](https://external-secrets.io/latest/api/externalsecret/).
- **`externalSecret.target.name`**: leave empty to reuse the same name as the static app secret (`<release>-app`); then set **`secret.enabled: false`** so Helm does not create a conflicting Opaque Secret.
- Newer clusters may use **`apiVersion: external-secrets.io/v1`** — override **`externalSecret.apiVersion`** if your ESO version requires it.

---

## 6. Persistence (PVC)

Set **`persistence.enabled: true`** and adjust **`storageClass`**, **`size`**, and **`mountPath`**. The chart mounts the volume at **`persistence.mountPath`** on the main container. Ensure your cluster has a default **StorageClass** or set **`persistence.storageClass`** explicitly.

---

## 7. Autoscaling (HPA)

Set **`autoscaling.enabled: true`**, set **`resources.requests.cpu`**, and tune **`minReplicas`**, **`maxReplicas`**, and the CPU target. The chart refuses to render without that CPU request. Set **`resources.requests.memory`** as well if you set **`targetMemoryUtilizationPercentage`**. The cluster needs the **metrics-server** (or equivalent) for resource-based scaling.

---

## 8. ServiceAccount

By default **`serviceAccount.create: true`** creates a dedicated ServiceAccount and the Pod uses it. To use an existing account, set **`serviceAccount.create: false`** and **`serviceAccount.name`**.

**`serviceAccount.automount`** defaults to **`false`**: the Pod does not mount the Kubernetes API token unless you need **in-cluster** `kubectl`/client-go access. Set **`automount: true`** if your app talks to the API server.

**RBAC:** This chart does **not** create **`Role`**, **`ClusterRole`**, or **`RoleBinding`**. That is normal for a stateless web app that does not use the Kubernetes API. If your workload needs to watch resources or create Jobs, add a **`templates/rbac.yaml`** (or a subchart) with least-privilege rules.

---

## 9. Security defaults, Kyverno, and Pod Security Standards

**Kyverno** (and similar tools) usually enforce policy **cluster-wide** or **per namespace** — for example “drop all capabilities”, “require `seccompProfile`”, “disallow privileged pods”. Those policies apply to **whatever YAML** you install, including Helm charts.

**What this starter does:** `values.yaml` sets **`podSecurityContext.seccompProfile`**, **`securityContext.allowPrivilegeEscalation: false`**, and **`capabilities.drop: ["ALL"]`**, which matches many **Kyverno** / **Pod Security Standard** “baseline” style checks. It does **not** embed Kyverno **`ClusterPolicy`** objects: those belong in a **platform** / **cluster-addons** repo, not in every application chart (avoid duplicating policy CRs hundreds of times).

**What you still do outside the chart:**

- **PSS / Kyverno** on the **namespace** (e.g. `pod-security.kubernetes.io/enforce: restricted`) or cluster policies.
- **Image** allowlists, **sigstore** verification, **admission** for labels — platform concerns.
- Per-image tuning: **`runAsNonRoot`**, **`readOnlyRootFilesystem`**, **`runAsUser`**, and **emptyDir** mounts for writable temp/cache (default **nginx** may need overrides for stricter **restricted** profiles).

**Optional `NetworkPolicy`** (`networkPolicy.enabled`): **off** by default. Turning it **on** without **egress** rules that allow **DNS** (and your dependencies) can break the Pod. Example egress for **kube-dns** / **CoreDNS** in **`kube-system`** (labels vary by distribution — adjust for your cluster):

```yaml
networkPolicy:
  enabled: true
  ingress:
    - ports:
        - port: 80
          protocol: TCP
      # from: []  # tighten: namespaceSelector / podSelector for ingress controller or mesh
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

**`podDisruptionBudget`:** set **`podDisruptionBudget.enabled: true`** when **`replicaCount > 1`** or **HPA** is on, so voluntary disruptions do not take all replicas at once.

---

## 10. Istio service mesh (optional)

When the workload runs in an **[Istio](https://istio.io/)** mesh with **sidecar** injection, set **`istio.enabled: true`**. The chart then adds:

- **`sidecar.istio.io/inject`** — default **`"true"`**; use **`sidecarInjectAnnotation: "false"`** to opt out in a namespace that injects by default, or **`""`** to omit the annotation and follow only the **Namespace** label.
- **`istio.io/rev`** on the Pod when **`istio.revision`** is set (common for **revision-based** / canary control planes, e.g. **`1-22-1`**).
- **`istio.podAnnotations`** for proxy tuning (e.g. **`proxy.istio.io/config`**, resource requests).

**Service port name:** Istio infers protocol from the **Service** port **`name`**. This chart uses **`name: http`**, which is valid. For gRPC, use a name like **`grpc`** or **`grpc-something`**. Plain **`tcp-*`** avoids HTTP parsing when needed.

**Gateway / VirtualService / DestinationRule:** Ingress traffic through Istio is usually modeled with a **mesh** or **platform** chart ( **`Gateway`**, **`VirtualService`**, mTLS **`PeerAuthentication`**, **`AuthorizationPolicy`**). This starter does **not** create those by default — keep them with shared mesh config so every app chart does not duplicate routes.

**Istio ambient mode** (sidecar-less) uses **waypoints** and different labels; rely on your platform docs and namespace labels — you can still use **`istio.podAnnotations`** for any annotations your version expects.

Example:

```yaml
istio:
  enabled: true
  revision: "1-22-1"
  sidecarInjectAnnotation: "true"
  podAnnotations:
    proxy.istio.io/config: '{ "holdApplicationUntilProxyStarts": true }'
```

---

## What is included (summary)

| Resource | Template | Default |
|----------|----------|---------|
| Deployment | `deployment.yaml` | On |
| Service | `service.yaml` | On |
| Ingress (`networking.k8s.io/v1`) | `ingress.yaml` | **Off** — set `ingress.enabled` |
| HTTPRoute (Gateway API) | `httproute.yaml` | **Off** — set `httpRoute.enabled` |
| ConfigMap | `configmap.yaml` | **Off** — set `configMap.enabled` + `configMap.data` |
| Secret (Opaque, app env) | `secret.yaml` | **Off** — set `secret.enabled` + `secret.stringData` |
| ExternalSecret (ESO → Secret, app env) | `externalsecret.yaml` | **Off** — set `externalSecret.enabled` + store refs |
| PVC | `pvc.yaml` | **Off** — set `persistence.enabled` |
| HPA (`autoscaling/v2`) | `hpa.yaml` | **Off** — set `autoscaling.enabled` |
| ServiceAccount | `serviceaccount.yaml` | On (`serviceAccount.create: true`) |
| NetworkPolicy | `networkpolicy.yaml` | **Off** — set `networkPolicy.enabled` + rules |
| PodDisruptionBudget | `pdb.yaml` | **Off** — set `podDisruptionBudget.enabled` for HA |

TLS for public HTTPS hostnames is usually via **Ingress** `ingress.tls` (TLS Secret). The chart’s **Secret** template is for **application** secrets (`envFrom`), not for Ingress TLS by default.

---

## Example values snippet (many features on)

```yaml
ingress:
  enabled: true

autoscaling:
  enabled: true

configMap:
  enabled: true
  data:
    app.properties: |
      env=production

secret:
  enabled: true
  stringData:
    API_KEY: "use-sealed-secrets-or-external-secrets-in-prod"

persistence:
  enabled: true
  mountPath: /data

httpRoute:
  enabled: true
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
      sectionName: http
```

In real use you would **not** enable both full Ingress and HTTPRoute for the same app unless you intend to; the snippet above is for illustration of toggles.

---

## Package and publish (optional)

From the chart directory:

```bash
helm package .
```

This produces `<chart-name>-<version>.tgz`. Publishing to a Helm chart repository (HTTP index or OCI) is described in the [repository README](../../README.md).
