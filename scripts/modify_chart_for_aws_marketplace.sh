#!/bin/bash

FILE="./stable/ksoc-plugins/values.yaml"

GCR_REGISTRY_NAME="us.gcr.io/ksoc-public"
ECR_REGISTRY_NAME="public.ecr.aws/n8h5y2v5/rad-security"
ECR_PUBLIC_REGISTRY="public.ecr.aws/eks-distro/kubernetes"

AWS_MARKETPLACE_REGISTRY_NAME="709825985650.dkr.ecr.us-east-1.amazonaws.com/ksoc-labs"


sed -i "s|$ECR_PUBLIC_REGISTRY|$AWS_MARKETPLACE_REGISTRY_NAME|g" "$FILE"
sed -i "s|$GCR_REGISTRY_NAME|$AWS_MARKETPLACE_REGISTRY_NAME|g" "$FILE"
sed -i "s|$ECR_REGISTRY_NAME|$AWS_MARKETPLACE_REGISTRY_NAME|g" "$FILE"
sed -i '/# --/d' "$FILE"

yq e -i '.eksAddon.enabled = true' $FILE

rm ./stable/ksoc-plugins/templates/access-key-secret.yaml
