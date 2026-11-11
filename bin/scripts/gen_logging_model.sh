#!/usr/bin/env bash
#
# Run the Slate 3 generator for the Logging module. Bespoke (not the
# manager-pattern script) because Logging has no public/Impl pair under
# `Modules/Managers/<Name>Manager/`.
#
# Conventions:
#   * The only `@SlateEntity` source is `LogEntry.swift`. We pass it as
#     `--input` directly so the parser doesn't sweep `Generated/` and
#     re-parse what it just wrote.
#   * `--model-module` and `--runtime-module` are both `Logging` — the
#     generator omits `import Logging` from the generated files when the two
#     match, so the bridge / mutable / schema files don't self-import.
#   * Generated files land in `Modules/Foundation/Logging/Logging/Generated/`,
#     compiled as part of the same `Logging` target.

set -euo pipefail

INPUT_FILE="Modules/Foundation/Logging/Logging/LogEntry.swift"
OUTPUT_DIR="Modules/Foundation/Logging/Logging/Generated"

mkdir -p "${OUTPUT_DIR}"

mint run slate slate-generator generate \
    --input "${INPUT_FILE}" \
    --output "${OUTPUT_DIR}" \
    --schema-name "LoggingSlateSchema" \
    --model-module "Logging" \
    --runtime-module "Logging" \
    --prune
