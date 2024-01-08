#!/bin/bash
set -euo pipefail

VALUES_FILE_PATH="./stable/ksoc-plugins/values.yaml"
CHART_FILE_PATH="./stable/ksoc-plugins/Chart.yaml"

HELM_CHART_VERSION=$(yq e ".version" "$CHART_FILE_PATH")
HELM_CHART_REPO="ksoc-labs/ksoc-plugins"

RELEASE_NOTES_URL="https://github.com/ksoclabs/ksoc-plugins-helm-chart"

AWS_MARKETPLACE_PRODUCT_ID="prod-m7tlrvfq6yjzu"


CONTAINER_IMAGES="709825985650.dkr.ecr.us-east-1.amazonaws.com/ksoc-labs/falco-no-driver:0.36.2
709825985650.dkr.ecr.us-east-1.amazonaws.com/ksoc-labs/falcoctl:0.6.2\n"

PRODUCT_TITLE=$(aws marketplace-catalog describe-entity --entity-id "${AWS_MARKETPLACE_PRODUCT_ID}" --catalog AWSMarketplace --region us-east-1 | jq -r '.Details | fromjson | .Description.ProductTitle')

images=""
detected_images=$(yq e 'keys | .[]' "$VALUES_FILE_PATH")

for image in $detected_images; do
    repo=$(yq e ".${image}.image.repository" "$VALUES_FILE_PATH")
    tag=$(yq e ".${image}.image.tag" "$VALUES_FILE_PATH")

    # Check if both repository and tag are not null or empty
    if [ -n "$repo" ] && [ "$repo" != "null" ] && [ -n "$tag" ] && [ "$tag" != "null" ]; then
        images+="${repo}:${tag}\n"
    fi
done

# Append the images found in values.yaml with our Falco images
CONTAINER_IMAGES+="$images"

echo "Creating Change Set"
# For API Reference, see https://docs.aws.amazon.com/marketplace-catalog/latest/api-reference/container-products.html
CHANGE_SET=$(
jq --null-input \
    --arg RELEASE_NOTES_URL "$RELEASE_NOTES_URL" \
    --arg HELM_CHART_REPO "$HELM_CHART_REPO" \
    --arg HELM_CHART_VERSION "$HELM_CHART_VERSION" \
    --arg CONTAINER_IMAGES "$CONTAINER_IMAGES" \
    --arg PRODUCT_TITLE "$PRODUCT_TITLE" \
    --arg AWS_MARKETPLACE_PRODUCT_ID "$AWS_MARKETPLACE_PRODUCT_ID" \
    '{
       "Version": {
         "ReleaseNotes": "For detailed release notes, view our release notes for this version at: \($RELEASE_NOTES_URL)",
         "VersionTitle": "Chart Release v\($HELM_CHART_VERSION)"
       },
       "DeliveryOptions": [
         {
           "Details": {
             "HelmDeliveryOptionDetails": {
               "CompatibleServices": [
                 "EKS"
               ],
               "ContainerImages": ($CONTAINER_IMAGES | split( "\n" ) | map(select(. != "" ))),
               "Description": "The KSOC plugins are deployed in your EKS cluster with our Helm chart. The chart is open source and can be viewed here",
               "HelmChartUri": "709825985650.dkr.ecr.us-east-1.amazonaws.com/\($HELM_CHART_REPO):\($HELM_CHART_VERSION)",
               "QuickLaunchEnabled": false,
               "UsageInstructions": "Install with Helm or EKS Addon",
               "ReleaseName": "ksoc-plugins",
               "Namespace": "ksoc",
               "OverrideParameters": [
                  {
                    "Key": "ksoc.clusterName",
                    "Metadata": {
                      "Obfuscate": false,
                      "Label": "KSOC Cluster Name",
                      "Description": "The name of the cluster you wish to give to within the KSOC Platform"
                    }
                  },
                  {
                    "Key": "ksoc.base64AccessKeyId",
                    "Metadata": {
                      "Obfuscate": true,
                      "Label": "Base64 Access Key",
                      "Description": "The base64 encoded acess key given through the UI or the API of KSOC"
                    }
                  },
                  {
                    "Key": "ksoc.base64SecretKey",
                    "Metadata": {
                      "Obfuscate": true,
                      "Description": "The base64 encoded secrt key given through the UI or the API of KSOC",
                      "Label": "Base64 Secret Key"
                    }
                  }
                ],
             }
           },
           "DeliveryOptionTitle": "\($PRODUCT_TITLE)"
         }
       ]
     }

     | tostring |

     [
       {
         "ChangeType": "AddDeliveryOptions",
         "Entity": {
           "Identifier": $AWS_MARKETPLACE_PRODUCT_ID,
           "Type": "ContainerProduct@1.0"
         },
         "Details": .
       }
     ]
     ')

aws marketplace-catalog start-change-set --change-set-name "Publish version v${HELM_CHART_VERSION}" --catalog "AWSMarketplace" --region us-east-1 --change-set "$CHANGE_SET"
