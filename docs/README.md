# Documentation

Read in this order.

| | Document | Contents |
|---|----------|----------|
| 01 | [Hosting a Helm chart repository](01-hosting-helm-repo.md) | Classic repository: `index.yaml`, packages, GitHub Pages |
| 02 | [Publish workflow](02-publish-helm-workflow.md) | `.github/workflows/publish-helm.yml` |
| 03 | [Chart changelog](03-chart-changelog.md) | `CHANGELOG.md` and `artifacthub.io/changes` |
| 04 | [Helm OCI registries](04-helm-oci.md) | `helm push`, `helm install oci://`, Docker Hub paths |
| 05 | [OCI publish workflow](05-publish-helm-oci-workflow.md) | Optional `.github/workflows/publish-helm-oci.yml` |
| 06 | [Migrating a Helm chart repository to OCI](06-migrate-to-oci.md) | Moving consumers from the classic repository to OCI |
| 07 | [Artifact Hub](07-artifact-hub.md) | Registering the published repository |
| 08 | [Microservice chart standardization](08-microservices-helm-standardization.md) | Design note on starters for many service charts |
