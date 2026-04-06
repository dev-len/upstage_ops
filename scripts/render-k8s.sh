#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <kustomize-dir>" >&2
  exit 1
fi

readonly TARGET_DIR="$1"

kubectl kustomize "$TARGET_DIR"
