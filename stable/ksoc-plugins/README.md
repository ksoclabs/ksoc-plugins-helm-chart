# ksoc-plugins

A Helm chart to run the KSOC plugins

![Version: 1.0.21](https://img.shields.io/badge/Version-1.0.21-informational?style=flat-square)

## KSOC Plugins Architecture

The KSOC plugins helm chart comprises the following plugins:

- ksoc-sync
- ksoc-watch
- ksoc-sbom
- ksoc-guard

These plugins perform several different tasks, which will be explained below.

### ksoc-sync plugin
`ksoc-sync` is the plugin component synchronising Kubernetes resources to the customer cluster. Currently, only the `GuardPolicy` CRD is supported, but the mechanism is extensible and allows KSOC to sync different resource types in the future. The plugin fetches resources from the KSOC API. After executing them on the customer's cluster, the execution statuses are reported to the KSOC API via HTTP calls. By default, the interval between the fetches is 60 seconds.

### ksoc-watch plugin
`ksoc-watch` is the plugin component responsible for syncing cluster state back to Ksoc. On startup, a controller is created that follows the [Kubernetes Informer](https://pkg.go.dev/k8s.io/client-go/informers) pattern via the [SharedIndexInformer](https://pkg.go.dev/k8s.io/client-go@v0.26.0/tools/cache#SharedIndexInformer:~:text=type%20SharedIndexInformer-,%C2%B6,-type%20SharedIndexInformer%20interface) to target the resource types that we are interested in individually.
The first action of the service is to upload the entire inventory of the cluster. Once this inventory is up-to-date, the plugin tracks events only generated when we detect a change in the object (or resource) state.
In this way, we can avoid the degradation of the API server, which would occur if we were to poll for resources. Automatic reconciliation is run every 24h by default in case any delete events are lost and prevent KSOC from keeping track of stale objects.

### ksoc-sbom plugin
`ksoc-sbom` is the plugin responsible for calculating [SBOMs](https://en.wikipedia.org/wiki/Software_supply_chain) directly on the customer cluster. The plugin is run as an admission/mutating webhook, adding an image digest next to its tag if it's missing. This mutation is performed so [TOCTOU](https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use) does not impact the user. The image deployed is the image that KSOC scanned. It sees all new workloads and calculates SBOMs for them. It continuously checks the KSOC API to save time and resources to see if the SBOM is already known for any particular image digest. If not, it is being calculated and uploaded to KSOC for further processing.

### ksoc-guard plugin
`ksoc-guard` is the plugin responsible for executing `GuardPolicy` (in the form of Rego) against a specific set of Kubernetes resources during their admission to the cluster, either allowing the admission or denying it.
The configuration for the blocking logic can be found in the `ksocGuard` section of the helm chart values file; see [here](https://artifacthub.io/packages/helm/ksoc/ksoc-plugins?modal=values). If admission is blocked, it can be seen in the KSOC application under the Events tab for the specific cluster.
Finally, the plugin also acts as a mutating webhook that simply takes the `AdmissionReview.UID` and adds it as an annotation (`ksoc-guard/admission: xxx`). In the case of a blocked object, this gives KSOC an identifier to track what would otherwise be an ephemeral event.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| deployments.disableServiceMesh | bool | `true` | Whether to disable service mesh integration. |
| deployments.imagePullSecretName | string | `""` | The image pull secret name to use to pull container images. |
| deployments.nodeSelector | object | `{}` | The node selector to use for the plugin deployments. |
| deployments.tolerations | list | `[]` | The tolerations to use for the plugin deployments. |
| ksoc.accessKeySecretNameOverride | string | `""` | The name of the custom secret containing Access Key. |
| ksoc.apiUrl | string | `"https://api.ksoc.com"` | The base URL for the KSOC API. |
| ksoc.base64AccessKeyId | string | `""` | The ID of the Access Key used in this cluster (base64). |
| ksoc.base64SecretKey | string | `""` | The secret key part of the Access Key used in this cluster (base64). |
| ksoc.clusterName | string | `""` | The name of the cluster you want displayed in KSOC. |
| ksocBootstrapper.env | object | `{}` |  |
| ksocBootstrapper.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-bootstrapper"` | The image to use for the ksoc-bootstrapper deployment (located at https://console.cloud.google.com/gcr/images/ksoc-public/us/ksoc-bootstrapper). |
| ksocBootstrapper.image.tag | string | `"v0.0.13"` |  |
| ksocBootstrapper.podAnnotations | object | `{}` |  |
| ksocBootstrapper.resources.limits.cpu | string | `"100m"` |  |
| ksocBootstrapper.resources.limits.memory | string | `"64Mi"` |  |
| ksocBootstrapper.resources.requests.cpu | string | `"50m"` |  |
| ksocBootstrapper.resources.requests.memory | string | `"32Mi"` |  |
| ksocGuard.config.BLOCK_ON_ERROR | bool | `false` | Whether to block on error. |
| ksocGuard.config.BLOCK_ON_POLICY_VIOLATION | bool | `false` | Whether to block on policy violation. |
| ksocGuard.config.BLOCK_ON_TIMEOUT | bool | `false` | Whether to block on timeout. |
| ksocGuard.config.LOG_LEVEL | string | `"info"` | The log level to use. |
| ksocGuard.enabled | bool | `true` |  |
| ksocGuard.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-guard"` | The image to use for the ksoc-guard deployment (located at https://console.cloud.google.com/gcr/images/ksoc-public/us/ksoc-guard). |
| ksocGuard.image.tag | string | `"v0.0.74"` |  |
| ksocGuard.podAnnotations | object | `{}` |  |
| ksocGuard.replicas | int | `1` |  |
| ksocGuard.resources.limits.cpu | string | `"250m"` |  |
| ksocGuard.resources.limits.memory | string | `"500Mi"` |  |
| ksocGuard.resources.requests.cpu | string | `"100m"` |  |
| ksocGuard.resources.requests.memory | string | `"100Mi"` |  |
| ksocGuard.webhook.objectSelector | object | `{}` |  |
| ksocGuard.webhook.timeoutSeconds | int | `10` |  |
| ksocSbom.enabled | bool | `true` |  |
| ksocSbom.env | object | `{}` |  |
| ksocSbom.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-sbom"` | The image to use for the ksoc-sbom deployment (located at https://console.cloud.google.com/gcr/images/ksoc-public/us/ksoc-sbom). |
| ksocSbom.image.tag | string | `"v0.0.48"` |  |
| ksocSbom.podAnnotations | object | `{}` |  |
| ksocSbom.resources.limits.cpu | int | `1` |  |
| ksocSbom.resources.limits.memory | string | `"2Gi"` |  |
| ksocSbom.resources.requests.cpu | string | `"500m"` |  |
| ksocSbom.resources.requests.memory | string | `"1Gi"` |  |
| ksocSbom.webhook.timeoutSeconds | int | `10` |  |
| ksocSync.enabled | bool | `true` |  |
| ksocSync.env | object | `{}` |  |
| ksocSync.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-sync"` | The image to use for the ksoc-sync deployment (located at https://console.cloud.google.com/gcr/images/ksoc-public/us/ksoc-sync). |
| ksocSync.image.tag | string | `"v0.0.37"` |  |
| ksocSync.podAnnotations | object | `{}` |  |
| ksocSync.resources.limits.cpu | string | `"200m"` |  |
| ksocSync.resources.limits.memory | string | `"256Mi"` |  |
| ksocSync.resources.requests.cpu | string | `"100m"` |  |
| ksocSync.resources.requests.memory | string | `"128Mi"` |  |
| ksocWatch.enabled | bool | `true` |  |
| ksocWatch.env.RECONCILIATION_AT_START | bool | `false` | Whether to trigger reconciliation at startup. |
| ksocWatch.env.RECONCILIATION_INTERVAL | string | `"24h"` | How often should reconciliation be triggered. |
| ksocWatch.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-watch"` | The image to use for the ksoc-watch deployment (located at https://console.cloud.google.com/gcr/images/ksoc-public/us/ksoc-watch). |
| ksocWatch.image.tag | string | `"v0.0.56"` |  |
| ksocWatch.podAnnotations | object | `{}` |  |
| ksocWatch.resources.limits.cpu | string | `"250m"` |  |
| ksocWatch.resources.limits.memory | string | `"512Mi"` |  |
| ksocWatch.resources.requests.cpu | string | `"100m"` |  |
| ksocWatch.resources.requests.memory | string | `"128Mi"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.5.0](https://github.com/norwoodj/helm-docs/releases/v1.5.0)
