#!/usr/bin/env bash
#
# Run the Slate 3 generator for a single `${1}Manager`.
#
# Convention:
#   * `@SlateEntity` model structs live in
#     `Modules/Foundation/Models/${1}Models/` (the shared model module).
#   * Generated mutable / bridge / schema files land in
#     `Modules/Managers/${1}Manager/${1}ManagerImpl/Generated/`.
#   * Schema type is named `${1}SlateSchema`.
#   * `--prune` removes generated files no longer in the manifest, so
#     deleting a model row also cleans up its old `Database*` /
#     `*+SlateBridge.swift`.
#
# Usage:
#   bin/scripts/gen_manager_model.sh Event

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: $0 <ManagerName>"
    echo "Example: $0 Event"
    exit 1
fi

MGR="$1"

INPUT_DIR="Modules/Foundation/Models/${MGR}Models"
OUTPUT_DIR="Modules/Managers/${MGR}Manager/${MGR}ManagerImpl/Generated"

mkdir -p "${OUTPUT_DIR}"

mint run slate slate-generator generate \
    --input "${INPUT_DIR}" \
    --output "${OUTPUT_DIR}" \
    --schema-name "${MGR}SlateSchema" \
    --model-module "${MGR}Models" \
    --runtime-module "${MGR}ManagerImpl" \
    --prune
