#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -x

readonly STABLE_REPO_URL=https://charts.ksoc.com/stable/
readonly S3_BUCKET_STABLE=s3://charts/stable
readonly AWS_S3_BASE_CMD="aws --endpoint-url=https://7c6a595d23459bcfaae41060cc31c4d4.r2.cloudflarestorage.com s3"

main() {

  setup_aws_client

  if ! sync_repo stable "$S3_BUCKET_STABLE" "$STABLE_REPO_URL"; then
      log_error "Not all stable charts could be packaged and synced!"
  fi
}

setup_aws_client() {
  echo "Setting up AWS client..."

  mkdir -p ~/.aws

  # shellcheck disable=SC2129
  echo "[default]" >> ~/.aws/config
  echo "region=auto" >> ~/.aws/config
  echo "credential_source=Environment" >> ~/.aws/config

  # shellcheck disable=SC2129
  echo "[default]" >> ~/.aws/credentials
  echo "aws_access_key_id=${AWS_ACCESS_KEY_ID}" >> ~/.aws/credentials
  echo "aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}" >> ~/.aws/credentials
}

sync_repo() {
    local repo_dir="${1?Specify repo dir}"
    local bucket="${2?Specify repo bucket}"
    local repo_url="${3?Specify repo url}"
    local sync_dir="${repo_dir}-sync"
    local index_dir="${repo_dir}-index"

    echo "Syncing repo '$repo_dir'..."

    # Handle the case when the directory is empty.
    if [ -z "$(ls -A "$repo_dir")" ]; then
      printf "The directory %s does not contain any charts, skipping ... \n" "${repo_dir}"
      return 0
    fi

    mkdir -p "$sync_dir"
    if ! ${AWS_S3_BASE_CMD} cp "$bucket/index.yaml" "$index_dir/index.yaml"; then
        log_error "Exiting because unable to copy index locally. Not safe to proceed."
        exit 1
    fi

    local exit_code=0

    for dir in "$repo_dir"/*; do
        if helm dependency build "$dir"; then
            helm package --destination "$sync_dir" "$dir"
        else
            log_error "Problem building dependencies. Skipping packaging of '$dir'."
            exit_code=1
        fi
    done

    if helm repo index --url "$repo_url" --merge "$index_dir/index.yaml" "$sync_dir"; then
        # Move updated index.yaml to sync folder so we don't push the old one again
        mv -f "$sync_dir/index.yaml" "$index_dir/index.yaml"

        ${AWS_S3_BASE_CMD} sync --exclude index.yaml "$sync_dir" "$bucket"

        # Make sure index.yaml is synced last
        ${AWS_S3_BASE_CMD} cp "$index_dir/index.yaml" "$bucket/index.yaml"
    else
        log_error "Exiting because unable to update index. Not safe to push update."
        exit 1
    fi

    # Finally sync the artifacthub-repo.yml file
    ${AWS_S3_BASE_CMD} cp "artifacthub-repo.yml" "$bucket/artifacthub-repo.yml"

    ls -l "$sync_dir"

    return "$exit_code"
}

log_error() {
    printf '\e[31mERROR: %s\n\e[39m' "$1" >&2
}

main
