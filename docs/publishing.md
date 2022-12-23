# Publishing charts to our registry

As we have a number of custom helm charts we need a way to store them in a centralised location so that they can be used across all our EKS clusters.

This is made possible by the creation of a Helm Registry (https://helm.sh/docs/topics/registries/).

A registry is simply made up of two main parts:

- An `index.yaml` which indexes all the helm packages.

- A set of versioned helm chart packages (tarballs)

### Cloudflare

When a Pull Requests (PRs) in this repository is merged into the `main` branch the set of helm charts are uploaded to our helm registry.

The full script for this can be found [here](../bin/sync-repo-cloudflare.sh).
