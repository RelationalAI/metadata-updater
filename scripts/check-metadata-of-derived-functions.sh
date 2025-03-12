#!/bin/bash

FILES_TO_CHECK=$@

echo "Checking metadata of derived functions in the following files: $FILES_TO_CHECK"

julia --project=. -e "
    using Pkg
    Pkg.instantiate()

    # Convert the filenames into an array of strings
    filenames = split(\"$FILES_TO_CHECK\", \" \")

    using MetadataUpdater
    env = MetadataUpdater.fetch_metadatainfo_filenames(filenames)
    MetadataUpdater.print_summary(env)
    # WE NEED TO EXTRACT THE ROOT FOR THE METADATA REGISTRY TOML FILE!!!!!!!!

    # if !check(env)
    #     @error \"ERROR FOUND! NEED TO update the metadata registry with:
    #             using RAICode.MetadataRegistry
    #             MetadataRegistry.persist_metadata_registry_manifest()
    #     \"
    #     exit(1)
    # end
    # println(\"👍All Good! No discrepancies between source code and the metadata registry.\")
    exit(0)
"

# We use the same exit value as the julia script
exit $?
