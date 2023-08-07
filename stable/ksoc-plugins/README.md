# KSOC Plugins

## Introduction

This chart deploys the following plugins required for the [KSOC](https://ksoc.com/) platform.

- ksoc-sync
- ksoc-watch
- ksoc-sbom
- ksoc-guard
- ksoc-runtime

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
The configuration for the blocking logic can be found in the `ksocGuard` section of the helm chart values file; see below.

```yaml
ksocGuard:
  config:
    BLOCK_ON_POLICY_VIOLATION: true
```

If admission is blocked, it can be seen in the KSOC application under the Events tab for the specific cluster. Finally, the plugin also acts as a mutating webhook that simply takes the `AdmissionReview.UID` and adds it as an annotation (`ksoc-guard/admission: xxx`). In the case of a blocked object, this gives KSOC an identifier to track what would otherwise be an ephemeral event.

### ksoc-runtime plugin
`ksoc-runtime` utilizes system-level probes in order to analyze what is happening at the process level on each node, enabling KSOC to detect in real-time events that may indicate a security breach is occurring. It is not enabled by default. To enable this, please set the following in your values file.

```yaml
ksocRuntime:
  enabled: true
```

When `ksoc-runtime` is enabled an additional deployment can be seen. There is also a `DaemonSet` that deploys an eBPF pod on each node to gather the run-time information.

## Prerequisites

The remainder of this page assumes the following:

- An Account in KSOC already exists
- The user has obtained the `base64AccessKey` and `base64SecretKey` values required for the installation via the UI or the API
- The user has kubectl installed
- The user has Helm v3 installed
- The user has kubectl admin access to the cluster
- The KSOC pods have outbound port 443 access to `https://api.ksoc.com`

## Installing the Chart

### 1. Install cert-manager

[cert-manager](https://github.com/cert-manager/cert-manager) must be installed, as KSOC deploys [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)  that create certificates to secure their communication with the Kubernetes API. At present KSOC only supports cert-manager as the means of creating these certificates.

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
  --version v1.10.0 \
  --set installCRDs=true
```

A full list of available Helm values is on[ cert-manager's ArtifactHub page](https://artifacthub.io/packages/helm/cert-manager/cert-manager).

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

### 3. Configure KSOC helm repository

To install the KSOC plugins Helm chart, we need to configure access to the KSOC helm repository using the commands below:

```bash
helm repo add ksoc https://charts.ksoc.com/stable
helm repo update
```

If you already had KSOC's Helm chart installed, it is recommended to update it.

```bash
helm repo update ksoc
```

Verify the KSOC plugins Helm chart has been installed:

```bash
helm search repo ksoc
```

Example output (chart version may differ):

```bash
helm search repo ksoc
NAME                     	CHART VERSION	APP VERSION	DESCRIPTION
ksoc/ksoc-plugins        	1.0.20      	           	A Helm chart to run the KSOC plugins
```

### 4. Create cluster-specific values file

Next, we need to create a values file called `values.yaml` with the following content that includes the [base64AccessKeyId and base64SecretKey](https://docs.ksoc.com/docs/installation#add-cluster):

```yaml
ksoc:
  base64AccessKeyId: "YOURACCESSKEYID"
  base64SecretKey: "YOURSECRETKEY"
  clusterName: "please add a name here"
```

You can manually create the file or use `values.yaml`file downloaded from the KSOC UI.

**NOTE:** Be sure to set the `clusterName` value with a descriptive name of the cluster where you will be installing KSOC.

#### 4.1 Recommended installation

By default, a secret is created as part of our Helm chart, which we use to securely connect to KSOC. However, it is highly recommended that this secret is created outside of the helm installation and is just referenced in the Helm values.

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

KSOC’s ksoc-guard plugin integrates with the Kubernetes admission controller. All admission controller communications require TLS. KSOC’s Helm chart installs and ksoc-guard utilizes Let’s Encrypt to automate the issuance and renewal of certificates using the cert-manager add-on.

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

If you have enabled the `ksoc-runtime` plugin you should also see the following pods in a state of Running:

```bash
NAME                            READY   STATUS    RESTARTS   AGE
ksoc-runtime-6c854b998c-7jjzg   1/1     Running   0          1m
ksoc-runtime-6c854b998c-p45g6   1/1     Running   0          1m
ksoc-runtime-6c854b998c-pmgtf   1/1     Running   0          1m

# The number of pods below should equal the number of nodes in your cluster
ksoc-runtime-ds-m44z5           2/2     Running   0          1m
ksoc-runtime-ds-nb9cq           2/2     Running   0          1m
ksoc-runtime-ds-snx8b           2/2     Running   0          1m
ksoc-runtime-ds-wvh8n           2/2     Running   0          1m
```

If you don't see all the pods running within 2 minutes, please check the [Installation Troubleshooting](https://docs.ksoc.com/docs/installation-troubleshooting) page or contact KSOC support.

## Uninstalling the Chart

To uninstall the `ksoc-plugins` deployment:

```
helm uninstall ksoc -n ksoc
```

The command removes all the Kubernetes components associated with the chart and deletes the release.
