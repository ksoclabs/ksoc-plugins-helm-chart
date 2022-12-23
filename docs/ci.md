# CI

The following sections detail the CI tasks which run as part of this repository.

All checks above are executed within our `kubernetes-toolkit` container which can be [here](http://github.com/ksoc-private/docker-kubernetes-toolkit).

## Deprecation checks

Throughout the evolution of Kubernetes the API versions that specific resources use become deprecated.

A prime example of this was the API versions that became deprecated as part of the 1.16 release see [here](https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16/) for more information.

Therefore, to remain ahead of the curve we want to be making sure we are not using deprecated API versions within our helm charts prior to them being deployed to our EKS clusters.

This is made possible by leveraging the following tools:

- Rego policies - [https://www.openpolicyagent.org/docs/latest/policy-language](https://www.openpolicyagent.org/docs/latest/policy-language)
- Conftest - [http://github.com/open-policy-agent/conftest](http://github.com/open-policy-agent/conftest)

An example policy can be seen below:

```
# All resources under apps/v1beta1 and apps/v1beta2 - use apps/v1 instead
_deny = msg {
  apis := ["apps/v1beta1", "apps/v1beta2"]
  input.apiVersion == apis[_]
  msg := sprintf("%s/%s: API %s has been deprecated, use apps/v1 instead.", [input.kind, input.metadata.name, input.apiVersion])
}
```

The full list of  policies we use can be found [here](https://github.com/ksoc-private/docker-kubernetes-toolkit/-/tree/main/policies).

We execute Conftest to run the policies against our file(s) using:

```
conftest test -p /policies <file>.yaml
```

The full script we run as part of our helm chart CI can be [here](../bin/deprecation-checks).

At the time of writing this document our EKS clusters are running Kubernetes 1.21, but we are validating against deprecations up to and including Kubernetes 1.21.

## Linting

We also leverage [http://github.com/helm/chart-testing](http://github.com/helm/chart-testing) to lint our helm charts.

The configuration file for our linting can be [here](../test/ct.yaml).

We mainly use this to validate that chart versions are bumped when changes to them are made.

## Kubeval

We also validate the resources defined in the helm charts match the JSON schema definitions exactly for the version of Kubernetes we are using.

This is made possible by leveraging a tool called [kubeval](http://github.com/instrumenta/kubeval).

The full script we run as part of our helm chart CI can be [here](../bin/kubeval-each-chart).

## Documentation

We also leverage [helm-docs](https://github.com/norwoodj/helm-docs) to make sure all our Helm charts documentation is kept up to date.
