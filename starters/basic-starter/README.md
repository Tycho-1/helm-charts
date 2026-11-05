# basic-starter

Smallest useful chart in this repo: **`helm create`**-style layout, **without** Ingress, HPA, or Gateway API.

| Resource | When |
|----------|------|
| Deployment | Always |
| Service | Always |
| ServiceAccount | Default `create: true` |
| ConfigMap | `configMap.enabled: true` + `configMap.data` |
| Secret (Opaque, app env) | `secret.enabled: true` + `secret.stringData` |

When both ConfigMap and Secret are enabled, the Pod uses **`envFrom`** so keys become environment variables.

**Security defaults** (same idea as **webapp-starter**): **`seccompProfile: RuntimeDefault`**, **`allowPrivilegeEscalation: false`**, **`capabilities.drop: ["ALL"]`**, **`serviceAccount.automount: false`**. There is **no** `NetworkPolicy`, **PDB**, or **RBAC** here — add templates if the app needs them, or use **webapp-starter**. **Kyverno** / **PSS** policies still apply at the **cluster**; this chart only supplies sane Pod defaults.

**Istio:** set **`istio.enabled: true`** for sidecar injection annotations and optional **`istio.revision`** (see [webapp-starter README §10](../webapp-starter/README.md#10-istio-service-mesh-optional)).

**Create a chart under `charts/` (this repo’s convention):**

```bash
./scripts/new-chart-from-starter.sh <your-app> basic-starter
```

**Or use as a Helm starter** (see [webapp-starter README](../webapp-starter/README.md#helm-environment--helm-env-important) for `HELM_DATA_HOME` / `starters/`):

```bash
helm create myapp -p "$(pwd)/starters/basic-starter"
```

Templates use the placeholder **`<CHARTNAME>`** as helper prefix; **`helm create`** replaces it with your chart name. If you **`cp -r`** the starter instead, replace it yourself: `grep -rl '<CHARTNAME>' charts/<your-app> | xargs sed -i 's/<CHARTNAME>/<your-app>/g'`.

**Before install:** set `image.repository` and `image.tag`. `service.port` is the Service port; `service.containerPort` is what the process listens on. Probe defaults are HTTP GET `/` for the nginx stand-in — change them, or set a probe to `{}` to omit it. `httpGet.port` must match `service.portName`. Enabling the ConfigMap or Secret adds a checksum annotation so a values change rolls the Deployment.

**Validate:** `helm lint .` and `helm template rel .`.

For a fuller web stack (Ingress, HTTPRoute, PVC, HPA, …), use **[webapp-starter](../webapp-starter/README.md)**.
