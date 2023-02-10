# KSOC Plugins

## Introduction

This chart deploys the plugins required for the [KSOC](https://ksoc.com/) platform.

## Prerequisites

The remainder of this page assumes the following:

- An Organization (child account) in KSOC already exists
- The user has obtained the `base64AccessKey` and `base64SecretKey` values required for the installation via the UI
- The user has kubectl installed
- The user has Helm v3 installed
- The user has kubectl admin access to the cluster

## Installing the Chart

### 1. Install cert-manager

[cert-manager](https://github.com/cert-manager/cert-manager) must be installed, as KSOC deploys [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)  that create certificates to secure their communication with the Kubernetes API. At present KSOC only supports cert-manager as the means of creating these certificates.

You can check if cert-manager is installed using the command below:

```
kubectl get pods -A | grep cert-manager
```

If the command above returns no results, you must install cert-manager into your cluster using the following commands:

**NOTE:** It may take up to 2 minutes for the `helm install`command below to complete.

```
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

```
kubectl get pods -n cert-manager
```

You should see the following pods (with slightly different generated IDs at the end) with a status of Running:

```
NAME                                     	 READY   STATUS	RESTARTS   AGE
cert-manager-7dc9d6599-5fj6g             	 1/1 	   Running   0      	1m
cert-manager-cainjector-757dd96b8b-hlqgp 	 1/1 	   Running   0      	1m
cert-manager-webhook-854656c6ff-b4zqp    	 1/1 	   Running   0      	1m
```

### 3. Configure KSOC helm repository

To install the KSOC plugins Helm chart, we need to configure access to the KSOC helm repository using the commands below:

```
helm repo add ksoc https://charts.ksoc.com/stable
helm repo update
```

If you already had KSOC's Helm chart installed, it is recommended to update it.

```
helm repo update ksoc
```

Verify the KSOC plugins Helm chart has been installed:

```
helm search repo ksoc
```

Example output:

```
helm search repo ksoc
NAME                     	CHART VERSION	APP VERSION	DESCRIPTION
ksoc/ksoc-plugins        	1.0.7       	           	A Helm chart to run the KSOC plugins
```

### 4. Create cluster-specific values file

Next, we need to create a values file called `values.yaml` with the following content that includes the [base64AccessKeyId and base64SecretKey](https://docs.ksoc.com/docs/installation#add-cluster):

```
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

```
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

```
ksoc:
  clusterName: "please add a name here"
  accessKeySecretNameOverride: "ksoc-access-key"
```

KSOC’s ksoc-guard plugin integrates with the Kubernetes admission controller. All admission controller communications require TLS. KSOC’s Helm chart installs and ksoc-guard utilizes Let’s Encrypt to automate the issuance and renewal of certificates using the cert-manager add-on.

### 5. Installing the KSOC plugins

Finally, you can install ksoc-plugins using the following command:

**NOTE:** It may take up to 2 minutes for the `helm install`command below to complete.

```
helm install \
  ksoc ksoc/ksoc-plugins \
  --namespace ksoc \
  --create-namespace \
  -f values.yaml
```

### 6. Verify KSOC plugins

Now we have installed the KSOC plugins, we need to validate that it is running successfully. This can be achieved using the command below:

```
kubectl get pods -n ksoc
```

You should expect to see the following pods in a state of Running:

```
ksoc-guard-774d79f4b7-b8fhr   2/2 	Running   0      	1m
ksoc-sbom-6db8f6fcb-f9n6p     2/2 	Running   0      	1m
ksoc-sync-774b47cb47-gms9d    1/1 	Running   0      	1m
ksoc-watch-8f5688cbb-pvcws    1/1 	Running   0      	1m
```

If you don't see all the pods running within 2 minutes, please check the [Installation Troubleshooting](https://docs.ksoc.com/docs/installation-troubleshooting) page or contact KSOC support.

## Uninstalling the Chart

To uninstall the `ksoc-plugins` deployment:

```
helm uninstall ksoc -n ksoc
```

The command removes all the Kubernetes components associated with the chart and deletes the release.
