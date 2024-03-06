# Helm charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/ksoc)](https://artifacthub.io/packages/search?repo=ksoc)

This repository contains the source for the packaged and versioned charts released on Artifacthub for the [`KSOC Plugins Helm repository`](https://artifacthub.io/packages/helm/ksoc/ksoc-plugins).

The charts in the `stable` directory in the `main` branch match the latest packaged charts in the chart repository.

The purpose of this repository is to provide a place for maintaining and contributing KSOC specific charts.

The repository has CI processes in place for managing the releasing of charts into the helm repository.

## Prerequisites

Before contributing to this repository it is recommended you read the documentation [here](docs/pre-reqs.md)

## CI

For a detailed description of all CI performed as part of this repository please see [here](docs/ci.md).

## Publishing

For a detailed description of how we publish charts to our registry please see [here](docs/publishing.md).

## How do I enable the KSOC repositories for Helm?

For a step-by-step guide on how to add the KSOC helm repositories locally please see [here](docs/adding-helm-repo-locally.md).

## Supported Kubernetes Versions

This chart repository supports the latest and previous minor versions of Kubernetes.

For example, if the latest minor release of Kubernetes is 1.22 then 1.21 and 1.22 are supported.

## Contributing Guidelines

Contributions are welcome via GitHub pull requests. Please see [here](CONTRIBUTING.md) for more information.
