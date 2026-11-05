# 08. Microservice chart standardization

Design note for standardizing a set of microservice charts on a few Helm starters, so deployments stay consistent and reviewable without making every service identical. `starters/basic-starter` and `starters/webapp-starter` in this repository are a reference implementation.

---

## 1. Executive summary

| Item | Proposal |
|------|-----------|
| **Situation** | Many microservices each have their own Helm chart; quality and patterns **diverge** (security defaults, secrets, networking, CI, naming). |
| **Idea** | Define **3–5 chart archetypes** (patterns), implement each as a **Helm starter** (or golden chart), then **regenerate or refactor** each service chart from the closest archetype. |
| **Per-service work** | **`Chart.yaml`**, **`values.yaml`**, and only the **diffs** that are truly special (ports, probes, env, resources, flags)—not a bespoke chart layout per team. |
| **Outcome** | One **reviewable standard**, simpler **onboarding**, safer **defaults**, and **faster** security or platform changes (update the starter, roll out). |

This is a **proven approach** at many organizations: constrain **structure** and **defaults**; allow **values** and small template overrides for **behavior**.

---

## 2. Why change?

Typical problems when charts grow organically:

- **Inconsistent security:** Some charts omit `securityContext`, run as root, mount the service account token unnecessarily, or ship secrets in plain `values.yaml`.
- **Inconsistent operations:** Mixed use of Ingress vs Gateway API, HPA, PDB, probes, resource limits—hard to support on-call.
- **Review fatigue:** Every MR reinvents patterns; reviewers must re-validate the same concerns.
- **Platform drift:** Service mesh (e.g. Istio), external secrets, and policy (Kyverno / Pod Security) are applied **ad hoc** per chart.
- **CI/publish:** Different pipelines per repo; harder to mandate **lint**, **test**, **sign**, or **OCI** publishing.

Standardizing on **starters** does not remove all variation—it **channels** variation into **known places** (`values.yaml`, optional feature flags).

---

## 3. Proposed model: archetypes + starters

### 3.1 Map services to patterns

Before writing YAML, classify each microservice:

| Archetype | Typical workload | Example capabilities in the chart |
|-----------|------------------|-----------------------------------|
| **A — Minimal API / worker** | HTTP or gRPC service, no public Ingress in chart | Deployment, Service, probes, SA, optional ConfigMap/Secret/ESO |
| **B — Edge / web** | User-facing HTTP, TLS at edge | A + Ingress **or** HTTPRoute, optional HPA, PDB |
| **C — Stateful / disk** | Cache, upload dir, local volume | B or A + PVC, careful probes |
| **D — Batch / job** (optional) | CronJob or Job-heavy | Separate starter or subchart pattern |
| **E — Library / shared** (optional) | Config-only or dependency chart | Rare; most teams skip |

**~30 services** rarely need **30** unique chart **shapes**; they often cluster into **3–5** archetypes. The goal is to **name those patterns** and commit to them.

### 3.2 Implement patterns as Helm starters

Helm’s built-in mechanism is **chart starter packs**: a directory of chart files used with **`helm create -p <path>`**. See the official docs: **[Chart starter packs](https://helm.sh/docs/topics/charts/#chart-starter-packs)** and **[`helm create`](https://helm.sh/docs/helm/helm_create/)**.

Each archetype becomes a **starter** (a directory you pass to `helm create -p …` or copy from):

- **Single source of truth** for labels, probes structure, `securityContext`, Service naming, optional Istio annotations, External Secrets, NetworkPolicy toggles, etc.
- **Documentation** in one place (README per starter).
- **Versioning:** When the platform improves the starter, teams **merge or regenerate** charts and resolve diffs deliberately.

This reference repository already illustrates the idea with **`basic-starter`** and **`webapp-starter`**; your org would maintain **your** starters (which may include two more archetypes, e.g. **gRPC-optimized** or **worker-only**).

### 3.3 Per-service “specificities”

After scaffolding from a starter, each service only maintains:

- **`Chart.yaml`:** `name`, `version`, `appVersion`, description  
- **`values.yaml`:** image, replicas, env, resources, feature flags (`ingress.enabled`, `istio.enabled`, …)  
- **Rare template patches:** Only when a service truly cannot be expressed by values (document why in the chart README)

If many services need the **same** patch, that is a signal to **promote** the change into the **starter**, not copy-paste.

---

## 4. Alignment with best practices (what “good” includes)

Use the starters to **encode** defaults that match your **cluster policy** and **compliance** goals:

| Area | Starter / review expectation |
|------|--------------------------------|
| **Pod security** | `seccompProfile`, drop capabilities, no privilege escalation; document path to `runAsNonRoot` / `readOnlyRootFilesystem` per image |
| **Service account** | Dedicated SA; **no** token automount unless the app calls the Kubernetes API |
| **Secrets** | Prefer **External Secrets** (or equivalent); avoid committing real secrets |
| **Networking** | Clear story: mesh (Istio) vs Ingress; optional NetworkPolicy behind a flag |
| **High availability** | PDB when replicas > 1 or HPA enabled |
| **Observability** | Standard labels/annotations hooks (metrics, tracing) as agreed platform-wide |
| **CI** | `helm lint`, `helm template`, optional kubeconform; publish (HTTP index and/or **OCI**) from a **standard pipeline** |

**Kyverno / admission** still apply at **cluster** scope; charts should **produce manifests that pass** those policies by default.

---

## 5. Migration strategy (phased, low drama)

| Phase | Actions |
|-------|---------|
| **0 — Agree** | Pick archetypes, assign owners (platform + one pilot team). |
| **1 — Pilot (2–3 services)** | Scaffold from starters; run in **non-prod**; tune starters from feedback. |
| **2 — Playbook** | Short “how to migrate” doc: naming, versioning, CI, rollback, who approves starter changes. |
| **3 — Rollout** | Migrate remaining services in **batches** (e.g. by domain or blast radius). |
| **4 — Decommission** | Retire old chart branches or dirs; archive “before” for audit if needed. |

**Avoid “big bang”** all 30 at once unless you have strong automation and test environments.

**Versioning:** Treat chart **`version`** in `Chart.yaml` as **independent** from app **`appVersion`**. Migrating layout may warrant a **major** chart bump for consumers.

### 5.1 Replacing an old chart for one service (usually **no** uninstall)

You normally **do not** delete the release and reinstall from scratch. Keep the **same Helm release name** and **same namespace**, point **`helm upgrade`** at the **new** chart directory (or new chart version), and supply **values** that match the old behavior where needed.

| Approach | What to do |
|----------|------------|
| **In-place upgrade** | `helm upgrade <release> ./charts/<service> -n <ns> -f values.yaml` (add `--install` only if you also use it for first install). Helm computes a **diff** against the live objects and **patches** them. |
| **Same chart `name` in `Chart.yaml`?** | The **chart name** in `Chart.yaml` is metadata; it does not have to match the release name. Prefer **not** renaming the **Helm release** during migration so history and automation stay stable. |
| **Chart `version`** | **Bump** `Chart.yaml` **`version`** (often a **major** bump) when templates change a lot—so artifacts, repos, and rollbacks are clear. You **can** keep **`appVersion`** aligned with the container image if that was your convention. |

**What can go wrong (inconsistency or surprises):**

| Pitfall | Why it hurts | Mitigation |
|---------|----------------|------------|
| **Resource names change** | If `fullnameOverride`, `nameOverride`, or helper logic changes, Helm may **create new** Deployments/Services and **leave old** ones orphaned (or fail mid-upgrade). | Compare **`helm template`** output **before/after**; keep naming stable for the migration, or plan a **two-step** cut with downtime. |
| **Immutable K8s fields** | e.g. some **StatefulSet** / **PVC** fields cannot change. | Know your workload type; sometimes only **recreate** fixes it (planned maintenance). |
| **Deployment selector changes** | Kubernetes forbids editing `.spec.selector` in place. | Keep **selector labels** identical, or create a **new** Deployment and cut traffic (blue/green). |
| **Secrets / data loss** | Replacing a Helm-managed **Secret** template can **overwrite** keys if you rely on chart-generated secrets. | Prefer **External Secrets** or **adopt** existing secrets; use **`helm diff`** and read release notes. |
| **Hooks / ownership** | Resources with odd annotations or not owned by the release. | Audit `helm get manifest` before migration. |

**Practical checklist for one service:** `helm lint` → `helm template` vs old output → non-prod **`helm upgrade`** → smoke test → **`helm rollback`** if needed → prod upgrade. Optional: **[helm-diff](https://github.com/databus23/helm-diff)** plugin for a clear manifest delta.

### 5.2 Recommended flow: starter → new chart → `helm upgrade`

This is the **intended** migration path for one service:

1. **Generate** the chart from the right starter (`helm create <service> -p …/starter`, or an internal script).
2. **Edit `Chart.yaml`:** set **`name:`** to your usual chart/service identity; **bump `version:`** because templates changed (often a **major** bump); keep **`appVersion:`** aligned with the **application** / image if that is your team’s convention.
3. **Edit `values.yaml`** so behavior matches the old chart (image, replicas, env, ingress/mesh flags, resources). Use **`fullnameOverride`** / **`nameOverride`** if you must keep **identical Kubernetes resource names** during the cutover.
4. **Validate:** `helm lint`, `helm template` (diff vs old chart output if possible).
5. **Apply:** **`helm upgrade <existing-release-name> ./path/to/chart -n <namespace> -f …`** — same **release name** and **namespace** as today. Use **`helm install`** only when **no** release exists yet (new cluster or new service).

**What to keep “the same” vs what to bump:**

| Item | Keep same as today? |
|------|---------------------|
| Helm **release name** | **Yes** |
| **Namespace** | **Yes** |
| **`Chart.yaml` `name:`** | **Usually yes** |
| **`Chart.yaml` `appVersion:`** | **Often yes** (tracks the app) |
| **`Chart.yaml` `version:`** | **No — bump** (new chart package; same version string for a different tarball confuses repos, OCI, and rollbacks) |

**Is this OK?** Yes — if you follow the checklist in §5.1 (especially **resource names** and **Deployment selectors**), try **non-prod** first, and use **`helm diff`** when available. The **starter** is only used to **produce** the chart directory; **`helm upgrade`** only consumes that chart—ongoing upgrades do not reference the starter.

---

## 6. Roles and governance

| Role | Responsibility |
|------|------------------|
| **Platform / SRE** | Owns starter repos, breaking changes, alignment with cluster policy and mesh |
| **Security** | Signs off on defaults (secrets, PSS, optional policy snippets) |
| **Service teams** | Own **values** and app-specific behavior; propose starter improvements via PR |
| **Architecture** | Keeps the **archetype list** small; resists one-off chart families without justification |

**Change control:** Updates to starters should be **reviewed** and **released** with notes (e.g. “webapp-starter v2: default PDB when HPA on”).

---

## 7. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| **“One size fits none”** | Multiple starters + values flags; escalate repeated exceptions into the starter |
| **Migration breaks prod** | Pilot first; parity checks (`helm template` diff, staging rollout) |
| **Teams lack Helm skills** | Starter README + office hours; generated charts reduce cognitive load |
| **Starter churn** | Semantic versioning of starters; announce deprecations |

---

## 8. Success criteria

- **≥90%** of microservice charts match an **approved archetype** (or documented exception).  
- **New services** scaffold from a starter in **under one day** without platform babysitting.  
- **Security scans / policy checks** pass by default on templated manifests.  
- **On-call** can assume common probe, rollout, and networking patterns.

---

## 9. Decisions

Record these before a migration starts:

1. Whether microservice charts adopt the archetype and starter approach.
2. Which team owns the starter repository and the migration notes.
3. Which two or three services are the pilot.

---

## 10. Appendix: this repository

This repository includes:

- **`starters/basic-starter`** and **`starters/webapp-starter`** as **examples** of the pattern (security defaults, optional External Secrets, Istio hooks, optional NetworkPolicy/PDB on webapp).  
- **`scripts/new-chart-from-starter.sh`** for **CI-friendly** chart generation.  
- Docs on **publish**, **OCI**, and **GitHub Actions** (adaptable to GitLab).

Other starter sets can follow the same process (archetypes, then starters, then migration). The file layout in this repository is one implementation, not a requirement.

**Helm documentation:** [Chart starter packs](https://helm.sh/docs/topics/charts/#chart-starter-packs) · [`helm create`](https://helm.sh/docs/helm/helm_create/)
