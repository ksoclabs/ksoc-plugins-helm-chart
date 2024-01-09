#!/bin/bash

# Path to the YAML file
yaml_file="./stable/ksoc-plugins/values.yaml"

# Initialize the 'image_pairs' string
image_pairs=""

# Read each top-level key in the YAML file
keys=$(yq e 'keys | .[]' "$yaml_file")

# Iterate over each key
for key in $keys; do
    # Extract the repository and tag values
    repo=$(yq e ".${key}.image.repository" "$yaml_file")
    tag=$(yq e ".${key}.image.tag" "$yaml_file")

    # Check if both repository and tag are not null or empty
    if [ -n "$repo" ] && [ "$repo" != "null" ] && [ -n "$tag" ] && [ "$tag" != "null" ]; then
        # Append to 'image_pairs' string with a newline
        image_pairs+="${repo}:${tag}\n"
    fi
done

# Print the 'image_pairs' string
echo -e "$image_pairs"
