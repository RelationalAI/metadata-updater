#!/bin/bash

FILES_TO_CHECK=$@

# echo "Checking metadata of derived functions in the following files: $FILES_TO_CHECK"

METAUPDATER_PATH=$(dirname $0)/..
RAICODE_PATH=$PWD
echo "RAICODE_PATH: $RAICODE_PATH"

# Check if Julia is installed and accessible
if ! command -v julia >/dev/null 2>&1; then
    echo "Error: Julia is not installed or not in your PATH." >&2
    echo "Exiting with 0" >&2
    exit 0
fi

julia --startup-file=no --history-file=no --project=$METAUPDATER_PATH -e "
    using Pkg
    Pkg.instantiate()

    # Convert the filenames into an array of strings
    filenames = split(\"$FILES_TO_CHECK\", \" \")
    filenames = [string(x) for x in filenames]

    using MetadataUpdater
    env = MetadataUpdater.fetch_metadatainfo_filenames(filenames)
    MetadataUpdater.print_summary(env)
    # WE NEED TO EXTRACT THE ROOT FOR THE METADATA REGISTRY TOML FILE!!!!!!!!

    if !check(env)
        @error \"ERROR FOUND! NEED TO update the metadata registry with:
                using RAICode.MetadataRegistry
                MetadataRegistry.persist_metadata_registry_manifest()
        \"
        exit(1)
    end
    println(\"👍All Good! No discrepancies between source code and the metadata registry.\")
    exit(0)
"

# We use the same exit value as the julia script
exit $?
