#!/bin/bash

# Ensure brew is in the path (for mint, which we installed with `make bootstrap`)
export PATH="/opt/homebrew/bin:$PATH"

# Clearing these which swift commands seem to dislike
export SWIFT_DEBUG_INFORMATION_FORMAT=
export SWIFT_DEBUG_INFORMATION_VERSION=

shopt -s nocasematch
if [[ "${RUN_DESTINATION_DEVICE_NAME}" =~ "preview" ]]; then
    echo "Aborting prebuild because this is a preview build"
    exit 0
fi

# Only run for debug configurations
if [ -n "$CONFIGURATION" ]; then
    if [ "$CONFIGURATION" != "Debug" ]; then
        echo "This tool is only run for debug configurations"
        exit 0
    fi
fi

# Make sure we're at the project root path; WORKSPACE_PATH is inside WeatherShmeather.xcodeproj/project.xcworkspace/
if [ -n "$WORKSPACE_PATH" ]; then
    cd "${WORKSPACE_PATH}/../.."
fi

# Set the working directory to the root of the project if SRCROOT is set -- this is more accurate than WORKSPACE_PATH
if [ -n "$SRCROOT" ]; then
    echo "setting working directory to $SRCROOT"
    cd "$SRCROOT"
fi

# ------------------------------------------------------------------------------------------------
# Re-generate the resources if any changed since last run
# ------------------------------------------------------------------------------------------------

echo "Checking resource manifest for changed resources"
MANIFEST=".cache/resource_manifest.txt"

# Check if the input file is readable
if [ ! -r "$MANIFEST" ]; then
    echo "The manifest could not be read; generating a new one"
    make resources
    exit 0
fi

MANIFEST_CREATED=`stat -f %m $MANIFEST`

# Process each directory in the file
while IFS= read -r directory || [ -n "$directory" ]; do
    LAST_MODIFIED=`find "$directory" -type f -exec stat -f "%m" {} \; | sort -nr | head -n 1`

    if [ $LAST_MODIFIED -gt $MANIFEST_CREATED ]; then
        echo "Resources changed: $directory ($LAST_MODIFIED > $MANIFEST_CREATED)"
        PARENT=`dirname "$directory"`
        mint run velocity generate-resources --modules-path "$PARENT" --swift-package Modules
    fi
done < "$MANIFEST"

# ------------------------------------------------------------------------------------------------
# Generate the modules package if any imports changed
# ------------------------------------------------------------------------------------------------

IMPORT_SHA_FILE=".cache/import_sha.txt"
IMPORT_SHA=`git diff -- "*.swift" | grep -E "^[+-].*(import|internal import|@testable import|@preconcurrency import|@_exported import)" | sha1sum | awk '{print $1}'`
EXISTING_SHA=`cat $IMPORT_SHA_FILE 2>/dev/null`
if [ "$IMPORT_SHA" != "$EXISTING_SHA" ]; then
    echo "Imports changed: [$IMPORT_SHA] != [$EXISTING_SHA]"
    make modules
fi

echo $IMPORT_SHA > $IMPORT_SHA_FILE

# ------------------------------------------------------------------------------------------------
# Format anything modified and update the manifest timestamp
# ------------------------------------------------------------------------------------------------

make format
touch -m $MANIFEST
