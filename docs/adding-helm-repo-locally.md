# Adding the helm repository locally

To add the KSOC chart repository for your local client, run the following:

```
helm repo add ksoc https://charts.ksoc.com/stable
"ksoc" has been added to your repositories
```

You can then run `helm search repo ksoc` to see the charts and their available versions.

You can now install charts using `helm install ksoc/<chart>`.

For more information on using Helm, refer to the [Helm documentation](https://github.com/kubernetes/helm#docs).
