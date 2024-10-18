# RAD Security Plugins

## Introduction

This chart deploys the following plugins required for the [RAD Security](https://rad.security/) platform(former KSOC):

- ksoc-sync
- ksoc-watch
- ksoc-sbom
- ksoc-guard
- ksoc-node-agent

These plugins perform several different tasks, which will be explained below.

### ksoc-sync plugin

`ksoc-sync` is the plugin component synchronising Kubernetes resources to the customer cluster. Currently, only the `GuardPolicy` CRD is supported, but the mechanism is extensible and allows RAD Security to sync different resource types in the future. The plugin fetches resources from the RAD Security API. After executing them on the customer's cluster, the execution statuses are reported to the RAD Security API via HTTP calls. By default, the interval between the fetches is 60 seconds.

### ksoc-watch plugin

`ksoc-watch` is the plugin component responsible for syncing cluster state back to RAD Security. On startup, a controller is created that follows the [Kubernetes Informer](https://pkg.go.dev/k8s.io/client-go/informers) pattern via the [SharedIndexInformer](https://pkg.go.dev/k8s.io/client-go@v0.26.0/tools/cache#SharedIndexInformer:~:text=type%20SharedIndexInformer-,%C2%B6,-type%20SharedIndexInformer%20interface) to target the resource types that we are interested in individually.
The first action of the service is to upload the entire inventory of the cluster. Once this inventory is up-to-date, the plugin tracks events only generated when we detect a change in the object (or resource) state.
In this way, we can avoid the degradation of the API server, which would occur if we were to poll for resources. Automatic reconciliation is run every 24h by default in case any delete events are lost and prevent RAD Security from keeping track of stale objects.

### ksoc-sbom plugin

`ksoc-sbom` is the plugin responsible for calculating [SBOMs](https://en.wikipedia.org/wiki/Software_supply_chain) directly on the customer cluster. The plugin is run as an admission/mutating webhook, adding an image digest next to its tag if it's missing. This mutation is performed so [TOCTOU](https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use) does not impact the user. The image deployed is the image that RAD Security scanned. It sees all new workloads and calculates SBOMs for them. It continuously checks the RAD Security API to save time and resources to see if the SBOM is already known for any particular image digest. If not, it is being calculated and uploaded to RAD Security for further processing. By default we use `cyclonedx-json` format for SBOMs, but it can be changed to `spdx-json` or `syft-json` by setting the `SBOM_FORMAT` environment variable in the `values.yaml` file. To prevent the plugin from mutating the `Pod` resource, set the `MUTATE_IMAGE` and `MUTATE_ANNOTATIONS` environment variables to `false`. If observe a performance degradation while deploying new workloads, you can improve it significantly by disabling the mutation of the image tag and annotations.

```yaml
ksocSbom:
  env:
    SBOM_FORMAT: cyclonedx-json
    MUTATE_IMAGE: true
    MUTATE_ANNOTATIONS: false
```

### ksoc-guard plugin

`ksoc-guard` is the plugin responsible for executing `GuardPolicy` (in the form of Rego) against a specific set of Kubernetes resources during their admission to the cluster, either allowing the admission or denying it.
The configuration for the blocking logic can be found in the `ksocGuard` section of the helm chart values file; see below.

```yaml
ksocGuard:
  config:
    BLOCK_ON_POLICY_VIOLATION: true
```

If admission is blocked, it can be seen in the RAD Security application under the Events tab for the specific cluster. Finally, the plugin also acts as a mutating webhook that simply takes the `AdmissionReview.UID` and adds it as an annotation (`ksoc-guard/admission: xxx`). In the case of a blocked object, this gives RAD Security an identifier to track what would otherwise be an ephemeral event.

### ksoc-node-agent plugin

`ksoc-node-agent` is the plugin responsible for gathering runtime information from the nodes in the cluster. The plugin is not enabled by default. To enable the plugin, set the `enabled` value to `true` in your values file.

```yaml
ksocNodeAgent:
  enabled: true
```

When `ksoc-node-agent` is enabled an additional daemonset can be seen in the cluster. The daemonset is responsible for collecting runtime information from the nodes in the cluster. The information collected includes the following:

- Process information
- Network information
- Filesystem information
- Container information

By default the plugin uses `containerd` as a container runtime. If you are using `docker` or `crio-o` as your container runtime, you can enable it by configuring collectors in the `values.yaml` file.

```yaml
ksocNodeAgent:
  enabled: true
  agent:
    collectors:
      containerd:
        enabled: true
        socket: /run/containerd/containerd.sock
      crio:
        enabled: false
        socket: /run/crio/crio.sock
      docker:
        enabled: false
        socket: /run/docker.sock
```

Each plugin pod contains `agent` and `exporter` containers. The `agent` container is responsible for collecting runtime information from the nodes in the cluster. The `exporter` container is responsible for exporting the collected information to the RAD Security platform.

The information collected is sent to the RAD Security platform for further processing. For more information on the `ksoc-node-agent` plugin, please see the [RAD Security Runtime documentation](https://docs.rad.security/docs/ksoc-node-agent)

### k9 plugin
`k9` is a plugin that responds in-cluster to commands from the Rad Security platform. The plugin will poll the Rad Security backend, and does not require any ingress to the cluster.  The plugin is not enabled by default. Individual capabilities must be opted-into by the user, and the plugin will only respond to commands that are explicitly enabled.  To enable a capability, please enable the plugin with `enabled: true` and set the capabilities you wish to enable to `true` in your values file.

```yaml
k9:
  enabled: true
  capabilities:
    enableTerminatePod: true
    enableTerminateNamespace: true
    enableQuarantine: true
    enableGetLogs: true
    enableLabelPod: true
```

Terminate Pod: Allows the plugin to terminate a pod in the cluster.
Terminate Namespace: Allows the plugin to terminate a namespace in the cluster.
Quarantine: Allows the plugin to quarantine a pod in the cluster via a NetworkPolicy to prevent it from communicating over the network.
Get Logs: Allows the plugin to retrieve logs from a pod in the cluster.
Label Pod: Allows the plugin to label a pod in the cluster.

## Prerequisites

The remainder of this page assumes the following:

- An Account in RAD Security already exists
- The user has obtained the `base64AccessKey` and `base64SecretKey` values required for the installation via the UI or the API
- The user has kubectl installed
- The user has Helm v3 installed
- The user has kubectl admin access to the cluster
- The KSOC pods have outbound port 443 access to `https://api.ksoc.com`

## Installing the Chart

### 1. Install cert-manager

[cert-manager](https://github.com/cert-manager/cert-manager) must be installed, as RAD Security deploys [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)  that create certificates to secure their communication with the Kubernetes API. At present RAD Security only supports cert-manager as the means of creating these certificates.

You can check if cert-manager is installed using the command below:

```bash
kubectl get pods -A | grep cert-manager
```

If the command above returns no results, you must install cert-manager into your cluster using the following commands:

**NOTE:** It may take up to 2 minutes for the `helm install`command below to complete.

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true
```

A full list of available Helm values is on[cert-manager's ArtifactHub page](https://artifacthub.io/packages/helm/cert-manager/cert-manager).

### 2. Verify cert-manager installation

Now we have installed cert-manager, we need to validate that it is running successfully. This can be achieved using the command below:

```bash
kubectl get pods -n cert-manager
```

You should see the following pods (with slightly different generated IDs at the end) with a status of Running:

```bash
NAME                                     	 READY   STATUS	RESTARTS   AGE
cert-manager-7dc9d6599-5fj6g             	 1/1 	   Running   0      	1m
cert-manager-cainjector-757dd96b8b-hlqgp 	 1/1 	   Running   0      	1m
cert-manager-webhook-854656c6ff-b4zqp    	 1/1 	   Running   0      	1m
```

### 3. Configure RAD Security helm repository

To install the RAD Security plugins Helm chart, we need to configure access to the KSOC helm repository using the commands below:

```bash
helm repo add ksoc https://charts.ksoc.com/stable
helm repo update
```

If you already had RAD Security's Helm chart installed, it is recommended to update it.

```bash
helm repo update ksoc
```

Verify the RAD Security plugins Helm chart has been installed:

```bash
helm search repo ksoc
```

Example output (chart version may differ):

```bash
helm search repo ksoc
NAME                     	CHART VERSION	APP VERSION	DESCRIPTION
ksoc/ksoc-plugins        	1.6.3        	           	A Helm chart to run the KSOC plugins
```

### 4. Create cluster-specific values file

Next, we need to create a values file called `values.yaml` with the following content that includes the [base64AccessKeyId and base64SecretKey](https://docs.rad.security/docs/installation#add-cluster):

```yaml
ksoc:
  base64AccessKeyId: "YOURACCESSKEYID"
  base64SecretKey: "YOURSECRETKEY"
  clusterName: "please add a name here"
```

You can manually create the file or use `values.yaml` file downloaded from the RAD Security UI.

**NOTE:** Be sure to set the `clusterName` value with a descriptive name of the cluster where you will be installing RAD Security.

#### 4.1 Recommended installation

By default, a secret is created as part of our Helm chart, which we use to securely connect to RAD Security. However, it is highly recommended that this secret is created outside of the helm installation and is just referenced in the Helm values.

The structure of the secret is as follows:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ksoc-access-key
  namespace: ksoc
data:
  access-key-id: "YOURACCESSKEYID"
  secret-key: "YOURSECRETKEY"
```

The secret can now be referenced in the Helm chart using the following values.yaml configuration:

```yaml
ksoc:
  clusterName: "please add a name here"
  accessKeySecretNameOverride: "ksoc-access-key"
```

RAD Security ksoc-guard plugin integrates with the Kubernetes admission controller. All admission controller communications require TLS. RAD Security Helm chart installs and ksoc-guard utilizes Let’s Encrypt to automate the issuance and renewal of certificates using the cert-manager add-on.

#### 4.2 AWS Secret Manager

If you are using AWS Secret Manager to store your access key, you can use the `awsSecretId` parameter to specify the secret ID. Secret ID could be the name of the secret or the full ARN. The service accounts need to have access to the secret in AWS, via IRSA or EKS Pod Identity. There is no need to provide `base64AccessKeyId` and `base64SecretKey` in this case.

```yaml
ksoc:
  awsSecretId: "arn:aws:secretsmanager:us-west-2:123456789012:secret:my-secret
```

Format of the secret in AWS Secret Manager:

```json
{
  "access-key-id": "value copied from the RAD Security UI, decoded from base64",
  "secret-key": "value copied from the RAD Security UI, decoded from base64"
}
```

If IRSA is used, following `serviceAccountAnnotations` should be added to the `values.yaml` file:

```yaml
ksocGuard:
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
ksocSbom:
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
ksocSync:
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
ksocWatch:
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
k9:
  enabled: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
ksocNodeAgent:
  enabled: true
  serviceAccountAnnotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/role-name-which-can-read-secrets
```

### 5. Installing the KSOC plugins

Finally, you can install ksoc-plugins using the following command:

**NOTE:** It may take up to 2 minutes for the `helm install`command below to complete.

```bash
helm install \
  ksoc ksoc/ksoc-plugins \
  --namespace ksoc \
  --create-namespace \
  -f values.yaml
```

### 6. Verify KSOC plugins

Now we have installed the KSOC plugins, we need to validate that it is running successfully. This can be achieved using the command below:

```bash
kubectl get pods -n ksoc
```

You should expect to see the following pods in a state of `Running`:

```bash
NAME                            READY   STATUS    RESTARTS   AGE
ksoc-guard-86959f7544-96hbl     1/1     Running   0          1m
ksoc-sbom-664bf566dc-bxm5c      1/1     Running   0          1m
ksoc-sync-769cd7c6fc-cxczq      1/1     Running   0          1m
ksoc-watch-7bf4d7b6b9-kqblh     1/1     Running   0          1m
```

If you have enabled the `ksoc-node-agent` plugin you should also see the following pods in a state of Running:

```bash
NAME                    READY   STATUS    RESTARTS   AGE
ksoc-node-agent-7jjzg   2/2     Running   0          1m
ksoc-node-agent-p45g6   2/2     Running   0          1m
ksoc-node-agent-pmgtf   2/2     Running   0          1m
```

The number of pods below should equal the number of nodes in your cluster

If you don't see all the pods running within 2 minutes, please check the [Installation Troubleshooting](https://docs.rad.security/docs/installation-troubleshooting) page or contact RAD Security support.

## Custom Resources support

`ksoc-watch` plugin optionally supports ingestion of _Custom Resources_ to the RAD Security platform. To use it
set `ksocWatch.ingestCustomResources` to `true` and configure `customResourceRules` in `values.yaml`.

For example, in order to ingest `your.com/ResourceA`, `your.com/ResourceB` and `your.com/ResourceC` `values.yaml` should include:

```yaml
ksocWatch:
  ingestCustomResources: true
  customResourceRules:
    allowlist:
    - apiGroups:
      - "your.com"
      resources:
      - "ResourceA"
      - "ResourceB"
      - "ResourceC"
```

Alternatively, you can ingest all _Custom Resources_ matching `your.com apiGroup` with a wildcard `*`:

```yaml
ksocWatch:
  ingestCustomResources: true
  customResourceRules:
    allowlist:
    - apiGroups:
      - "your.com"
      resources:
      - "*"
```

If you want to ingest `ResourceA` and `ResourceB` but exclude `ResourceC`, you should use `denylist`:

```yaml
ksocWatch:
  ingestCustomResources: true
  customResourceRules:
    allowlist:
    - apiGroups:
      - "your.com"
      resources:
      - "*"

    denylist:
    - apiGroups:
      - "your.com"
      resources:
      - "ResourceC"
```

## Node Agent Exec Filters

Node Agent allows to use wildcard rules to filtering command line arguments

To redact a secret used in `command secret=value`, you can use
the following Node Agent configuration:

```yaml
ksocNodeAgent:
  exporter:
    execFilters:
    - wildcard: "command secret=(*)"`.
```

All _wildcard groups_, i.e., `*` enclosed in parentheses will be redacted.

Wildcards not enclosed in parentheses can be used to match arguments that should not be redacted.

For example, the wildcard rule:
```yaml
ksocNodeAgent:
  exporter:
    execFilters:
    - wildcard: "command * secret=(*)"
```

result in the following redacted commands:

- `command -p secret=value` - `command -p secret=*****`
- `command --some-param secret=value` - `command --some-param secret=*****`

Simple patterns matching all commands can be also used. To redact `secret=value` in all commands, the following filter can be used:
```yaml
ksocNodeAgent:
  exporter:
    execFilters:
    - wildcard: "secret=(*)"
```

## Upgrading the Chart

Typically, we advise maintaining the most current versions of plugins. However, our [RAD Security](https://rad.security) plugins are designed to support upgrades between any two versions, with certain exceptions as outlined in our Helm chart changelog which you can access [here](https://artifacthub.io/packages/helm/ksoc/ksoc-plugins?modal=changelog).

The plugin image versions included in the Helm chart are collectively tested as a unified set. Individual plugin image versions are not tested in isolation for upgrades. It is strongly advised to upgrade the entire Helm chart as a complete package to ensure compatibility and stability.

### Workflow

To upgrade the version of the [RAD Security](https://rad.security) plugin's helm chart on your cluster, please follow the steps below.

1\. **Fetch the Latest Chart Version:** Acquire the most recent `ksoc-plugins` chart by running the following commands in your terminal

```bash
helm repo add ksoc https://charts.ksoc.com/stable
helm repo update ksoc
helm search repo ksoc
```

2\. **Perform the Upgrade:** Execute the upgrade by utilizing the following Helm command, making sure to retain your current configuration (values.yaml)

```bash
helm upgrade --install \
ksoc ksoc/ksoc-plugins \
--namespace ksoc \
--reuse-values
```

3\. **Confirm the Installation:** Verify that the upgrade was successful and the correct version is now deployed

```bash
helm list -n ksoc
```

### Helm chart changelog and updates

For full disclosure and to ensure you are kept up-to-date, we document every change, improvement, and correction in our detailed changelog for each version release. We encourage you to consult the changelog regularly to stay informed about the latest developments and understand the specifics of each update. Access the changelog for the [RAD Security](https://rad.security) plugins Helm chart at this [link](https://artifacthub.io/packages/helm/ksoc/ksoc-plugins?modal=changelog).

## Uninstalling the Chart

To uninstall the `ksoc-plugins` deployment:

```bash
helm uninstall ksoc -n ksoc
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| k9.backend.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-backend-agent"` |  |
| k9.backend.image.tag | string | `"v0.0.33"` |  |
| k9.capabilities.enableGetLogs | bool | `false` |  |
| k9.capabilities.enableLabelPod | bool | `false` |  |
| k9.capabilities.enableQuarantine | bool | `false` |  |
| k9.capabilities.enableTerminateNamespace | bool | `false` |  |
| k9.capabilities.enableTerminatePod | bool | `false` |  |
| k9.enabled | bool | `false` |  |
| k9.frontend.agentActionPollInterval | string | `"5s"` | The interval in which the agent polls the backend for new actions. |
| k9.frontend.image.repository | string | `"us.gcr.io/ksoc-public/ksoc-frontend-agent"` |  |
| k9.frontend.image.tag | string | `"v0.0.33"` |  |
| k9.nodeSelector | object | `{}` |  |
| k9.replicas | int | `1` |  |
| k9.resources.limits.cpu | string | `"250m"` |  |
| k9.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| k9.resources.limits.memory | string | `"512Mi"` |  |
| k9.resources.requests.cpu | string | `"100m"` |  |
| k9.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| k9.resources.requests.memory | string | `"128Mi"` |  |
| k9.serviceAccountAnnotations | object | `{}` |  |
| k9.tolerations | list | `[]` |  |
| ksoc.accessKeySecretNameOverride | string | `""` | The name of the custom secret containing Access Key. |
| ksoc.apiKey | string | `""` | The combined API key to authenticate with KSOC |
| ksoc.apiUrl | string | `"https://api.ksoc.com"` | The base URL for the KSOC API. |
| ksoc.awsSecretId | string | `""` | The Secret Name or Secret ARN containing the Access Key. If provided, plugins try to read the Access Key from the AWS Secret Manager. Plugins expect following keys in the secret: `access-key-id` and `secret-key`. If the secret is not found, the plugin falls back to the `base64AccessKeyId` and `base64SecretKey` values. If `awsSecretId` is provided service accounts needs to have access to the secret in AWS, via IRSA or EKS Pod Identity. |
| ksoc.base64AccessKeyId | string | `""` | The ID of the Access Key used in this cluster (base64). |
| ksoc.base64SecretKey | string | `""` | The secret key part of the Access Key used in this cluster (base64). |
| ksoc.clusterName | string | `""` | The name of the cluster you want displayed in KSOC. |
| ksoc.seccompProfile | object | `{"enabled":true}` | Enable seccompProfile for all KSOC pods |
| ksocBootstrapper.env | object | `{}` |  |
| ksocBootstrapper.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-bootstrapper"` | The image to use for the ksoc-bootstrapper deployment |
| ksocBootstrapper.image.tag | string | `"v1.1.9"` |  |
| ksocBootstrapper.nodeSelector | object | `{}` |  |
| ksocBootstrapper.podAnnotations | object | `{}` |  |
| ksocBootstrapper.resources.limits.cpu | string | `"100m"` |  |
| ksocBootstrapper.resources.limits.ephemeral-storage | string | `"100Mi"` |  |
| ksocBootstrapper.resources.limits.memory | string | `"64Mi"` |  |
| ksocBootstrapper.resources.requests.cpu | string | `"50m"` |  |
| ksocBootstrapper.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocBootstrapper.resources.requests.memory | string | `"32Mi"` |  |
| ksocBootstrapper.tolerations | list | `[]` |  |
| ksocGuard.config.BLOCK_ON_ERROR | bool | `false` | Whether to block on error. |
| ksocGuard.config.BLOCK_ON_POLICY_VIOLATION | bool | `false` | Whether to block on policy violation. |
| ksocGuard.config.BLOCK_ON_TIMEOUT | bool | `false` | Whether to block on timeout. |
| ksocGuard.config.ENABLE_WARNING_LOGS | bool | `false` | Whether to enable warning logs. |
| ksocGuard.config.LOG_LEVEL | string | `"info"` | The log level to use. |
| ksocGuard.enabled | bool | `true` |  |
| ksocGuard.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-guard"` | The image to use for the ksoc-guard deployment |
| ksocGuard.image.tag | string | `"v1.1.14"` |  |
| ksocGuard.nodeSelector | object | `{}` |  |
| ksocGuard.podAnnotations | object | `{}` |  |
| ksocGuard.replicas | int | `1` |  |
| ksocGuard.resources.limits.cpu | string | `"500m"` |  |
| ksocGuard.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| ksocGuard.resources.limits.memory | string | `"500Mi"` |  |
| ksocGuard.resources.requests.cpu | string | `"100m"` |  |
| ksocGuard.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocGuard.resources.requests.memory | string | `"100Mi"` |  |
| ksocGuard.serviceAccountAnnotations | object | `{}` |  |
| ksocGuard.tolerations | list | `[]` |  |
| ksocGuard.webhook.objectSelector | object | `{}` |  |
| ksocGuard.webhook.timeoutSeconds | int | `10` |  |
| ksocNodeAgent.agent.collectors.containerd.enabled | string | `nil` |  |
| ksocNodeAgent.agent.collectors.containerd.socket | string | `"/run/containerd/containerd.sock"` |  |
| ksocNodeAgent.agent.collectors.crio.enabled | string | `nil` |  |
| ksocNodeAgent.agent.collectors.crio.socket | string | `"/run/crio/crio.sock"` |  |
| ksocNodeAgent.agent.collectors.docker.enabled | bool | `false` |  |
| ksocNodeAgent.agent.collectors.docker.socket | string | `"/run/docker.sock"` |  |
| ksocNodeAgent.agent.collectors.runtimePath | string | `""` |  |
| ksocNodeAgent.agent.env.AGENT_LOG_LEVEL | string | `"INFO"` |  |
| ksocNodeAgent.agent.env.AGENT_TRACER_IGNORE_NAMESPACES | string | `"cert-manager,\nksoc,\nkube-node-lease,\nkube-public,\nkube-system\n"` |  |
| ksocNodeAgent.agent.eventQueueSize | int | `20000` |  |
| ksocNodeAgent.agent.grpcServerBatchSize | int | `2000` |  |
| ksocNodeAgent.agent.hostPID | string | `nil` |  |
| ksocNodeAgent.agent.mounts.volumeMounts | list | `[]` |  |
| ksocNodeAgent.agent.mounts.volumes | list | `[]` |  |
| ksocNodeAgent.agent.resources.limits.cpu | string | `"200m"` |  |
| ksocNodeAgent.agent.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| ksocNodeAgent.agent.resources.limits.memory | string | `"1Gi"` |  |
| ksocNodeAgent.agent.resources.requests.cpu | string | `"100m"` |  |
| ksocNodeAgent.agent.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocNodeAgent.agent.resources.requests.memory | string | `"128Mi"` |  |
| ksocNodeAgent.enabled | bool | `false` |  |
| ksocNodeAgent.exporter.env.EXPORTER_LOG_LEVEL | string | `"INFO"` |  |
| ksocNodeAgent.exporter.execFilters | list | `[]` | Allows to specify wildcard rules for filtering command arguments. |
| ksocNodeAgent.exporter.resources.limits.cpu | string | `"500m"` |  |
| ksocNodeAgent.exporter.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| ksocNodeAgent.exporter.resources.limits.memory | string | `"1Gi"` |  |
| ksocNodeAgent.exporter.resources.requests.cpu | string | `"100m"` |  |
| ksocNodeAgent.exporter.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocNodeAgent.exporter.resources.requests.memory | string | `"128Mi"` |  |
| ksocNodeAgent.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-runtime"` |  |
| ksocNodeAgent.image.tag | string | `"v0.1.2"` |  |
| ksocNodeAgent.nodeName | string | `""` |  |
| ksocNodeAgent.nodeSelector | object | `{}` |  |
| ksocNodeAgent.reachableVulnerabilitiesEnabled | bool | `true` |  |
| ksocNodeAgent.serviceAccountAnnotations | object | `{}` |  |
| ksocNodeAgent.tolerations | list | `[]` |  |
| ksocNodeAgent.updateStrategy.rollingUpdate.maxSurge | int | `0` | The maximum number of pods that can be scheduled above the desired number of pods. Can be an absolute number or percent, e.g. `5` or `"10%"` |
| ksocNodeAgent.updateStrategy.rollingUpdate.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable during the update. Can be an absolute number or percent, e.g.  `5` or `"10%"` |
| ksocNodeAgent.updateStrategy.type | string | `"RollingUpdate"` |  |
| ksocSbom.enabled | bool | `true` |  |
| ksocSbom.env.LOG_LEVEL | string | `"info"` | The log level to use.  Options are trace, debug, info, warn, error |
| ksocSbom.env.MUTATE_ANNOTATIONS | bool | `false` | Whether to mutate the annotations in pod spec by adding images digests. Annotations can be used to track image digests in addition to, or instead of the image tag mutation. |
| ksocSbom.env.MUTATE_IMAGE | bool | `true` | Whether to mutate the image in pod spec by adding digest at the end. By default, digests are added to images to ensure that the image that runs in the cluster matches the digest of the build.  Disable this if your continuous deployment reconciler requires a strict image tag match. |
| ksocSbom.env.SBOM_FORMAT | string | `"cyclonedx-json"` | The format of the generated SBOM. Currently we support: syft-json,cyclonedx-json,spdx-json |
| ksocSbom.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-sbom"` | The image to use for the ksoc-sbom deployment |
| ksocSbom.image.tag | string | `"v1.1.28"` |  |
| ksocSbom.nodeSelector | object | `{}` |  |
| ksocSbom.podAnnotations | object | `{}` |  |
| ksocSbom.resources.limits.cpu | string | `"1000m"` |  |
| ksocSbom.resources.limits.ephemeral-storage | string | `"25Gi"` | The ephemeral storage limit is set to 25Gi to cache and reuse image layers for the sbom generation. |
| ksocSbom.resources.limits.memory | string | `"2Gi"` |  |
| ksocSbom.resources.requests.cpu | string | `"500m"` |  |
| ksocSbom.resources.requests.ephemeral-storage | string | `"1Gi"` |  |
| ksocSbom.resources.requests.memory | string | `"1Gi"` |  |
| ksocSbom.serviceAccountAnnotations | object | `{}` |  |
| ksocSbom.tolerations | list | `[]` |  |
| ksocSbom.webhook.timeoutSeconds | int | `10` |  |
| ksocSync.enabled | bool | `true` |  |
| ksocSync.env | object | `{}` |  |
| ksocSync.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-sync"` | The image to use for the ksoc-sync deployment |
| ksocSync.image.tag | string | `"v1.1.13"` |  |
| ksocSync.nodeSelector | object | `{}` |  |
| ksocSync.podAnnotations | object | `{}` |  |
| ksocSync.resources.limits.cpu | string | `"200m"` |  |
| ksocSync.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| ksocSync.resources.limits.memory | string | `"256Mi"` |  |
| ksocSync.resources.requests.cpu | string | `"100m"` |  |
| ksocSync.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocSync.resources.requests.memory | string | `"128Mi"` |  |
| ksocSync.serviceAccountAnnotations | object | `{}` |  |
| ksocSync.tolerations | list | `[]` |  |
| ksocWatch.customResourceRules | object | `{"allowlist":[],"denylist":[]}` | Rules for Custom Resource ingestion containing allow- and denylists of rules specifying `apiGroups` and `resources`. E.g. `allowlist: apiGroups: ["custom.com"], resources: ["someResource", "otherResoure"]` Wildcards (`*`) can be used to match all. `customResourceRules.denylist` sets resources that should not be ingested. It has a priority over `customResourceRules.allowlist` to  deny resources allowed using a wildcard (`*`) match.  E.g. you can use `allowlist: apiGroups: ["custom.com"], resources: ["*"], denylist: apiGroups: ["custom.com"], resources: "excluded"` to ingest all resources within `custom.com` group but `excluded`. |
| ksocWatch.enabled | bool | `true` |  |
| ksocWatch.env.RECONCILIATION_AT_START | bool | `false` | Whether to trigger reconciliation at startup. |
| ksocWatch.image.repository | string | `"public.ecr.aws/n8h5y2v5/rad-security/rad-watch"` | The image to use for the ksoc-watch deployment |
| ksocWatch.image.tag | string | `"v1.1.23"` |  |
| ksocWatch.ingestCustomResources | bool | `false` | If set will allow ingesting Custom Resources specified in `customResourceRules` |
| ksocWatch.nodeSelector | object | `{}` |  |
| ksocWatch.podAnnotations | object | `{}` |  |
| ksocWatch.resources.limits.cpu | string | `"250m"` |  |
| ksocWatch.resources.limits.ephemeral-storage | string | `"1Gi"` |  |
| ksocWatch.resources.limits.memory | string | `"512Mi"` |  |
| ksocWatch.resources.requests.cpu | string | `"100m"` |  |
| ksocWatch.resources.requests.ephemeral-storage | string | `"100Mi"` |  |
| ksocWatch.resources.requests.memory | string | `"128Mi"` |  |
| ksocWatch.serviceAccountAnnotations | object | `{}` |  |
| ksocWatch.tolerations | list | `[]` |  |
| openshift.enabled | bool | `false` |  |
| priorityClass.description | string | `"The priority class for KSOC components"` |  |
| priorityClass.enabled | bool | `false` |  |
| priorityClass.globalDefault | bool | `false` |  |
| priorityClass.name | string | `"ksoc-priority"` |  |
| priorityClass.preemptionPolicy | string | `"PreemptLowerPriority"` |  |
| priorityClass.value | int | `1000000000` |  |
| workloads.disableServiceMesh | bool | `true` | Whether to disable service mesh integration. |
| workloads.imagePullSecretName | string | `""` | The image pull secret name to use to pull container images. |
