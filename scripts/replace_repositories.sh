#!/bin/bash

FILE="./stable/ksoc-plugins/values.yaml"
FALCO_DS_FILE="./stable/ksoc-plugins/templates/falco/falco-ds.yaml"

GCR_REGISTRY_NAME="us.gcr.io/ksoc-public"
FALCO_SEARCH="falcosecurity"

METADATA_COLLECTOR_LOCATION="./stable/ksoc-plugins/templates/metacollector/deployment.yaml"
METADATA_COLLECTOR_REGISTRY="docker.io/falcosecurity"

ECR_REGISTRY_NAME="709825985650.dkr.ecr.us-east-1.amazonaws.com/ksoc-labs"

sed -i "s|$GCR_REGISTRY_NAME|$ECR_REGISTRY_NAME|g" "$FILE"
sed -i "s|$FALCO_SEARCH|$ECR_REGISTRY_NAME|g" "$FALCO_DS_FILE"
sed -i "s|$METADATA_COLLECTOR_REGISTRY|$ECR_REGISTRY_NAME|g" "$METADATA_COLLECTOR_LOCATION"
sed -i '/# --/d' "$FILE"
