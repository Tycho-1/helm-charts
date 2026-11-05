# 03. Chart changelog

Each chart keeps its own changelog. This repository does not keep one shared changelog, and the publish workflow does not read these files. Add an entry when `version` in `Chart.yaml` changes. `charts/example` is the reference.

## Files

| File | Role |
|------|------|
| `charts/<name>/CHANGELOG.md` | What changed, for people reading the chart in git. Newest version first. |
| `artifacthub.io/changes` in `charts/<name>/Chart.yaml` | The same release, in the form [Artifact Hub](https://artifacthub.io/docs/topics/annotations/helm/#supported-annotations) shows for that version. |

Helm does not require either file. CI does not either. A pull request is published when `version` increases; `CHANGELOG.md` is not read. `helm lint`, `helm package`, and the GitHub Pages index work without a changelog.

## Release

1. Bump `version` in `Chart.yaml`.
2. Add a `## x.y.z` section at the top of `CHANGELOG.md`.
3. Replace the `artifacthub.io/changes` annotation so it describes **this** version only (not the full history).

```yaml
annotations:
  artifacthub.io/changes: |
    - kind: fixed
      description: Readiness probe path matches the application
    - kind: changed
      description: Default CPU request is 100m
```

`kind` is one of `added`, `changed`, `deprecated`, `removed`, `fixed`, `security`.

The annotation is optional until the repository is listed on Artifact Hub. Keep `CHANGELOG.md` either way.
