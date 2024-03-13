#!/bin/bash

FILE="./stable/ksoc-plugins/values.yaml"

GCR_REGISTRY_NAME="us.gcr.io/ksoc-public"
FALCO_SEARCH="falcosecurity"

METADATA_COLLECTOR_REGISTRY="docker.io/falcosecurity"

ECR_REGISTRY_NAME="709825985650.dkr.ecr.us-east-1.amazonaws.com/ksoc-labs"

sed -i "s|$GCR_REGISTRY_NAME|$ECR_REGISTRY_NAME|g" "$FILE"
sed -i "s|$FALCO_SEARCH|$ECR_REGISTRY_NAME|g" "$FILE"
sed -i "s|$METADATA_COLLECTOR_REGISTRY|$ECR_REGISTRY_NAME|g" "$FILE"
sed -i '/# --/d' "$FILE"
