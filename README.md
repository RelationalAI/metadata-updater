# MetadataUpdater

## Description

MetadataUpdater is a tool to extract metadata from the source code and check if it is
consistent with the TOML file. MetadataUpdater is meant to be used either standalone
through the helper script ./scripts/check_metadata-of-derived-functions.sh or as a part
of the CI pipeline (which ultimately call this script).

MetadataUpdater works as follow:

1. It extracts the metadata from the source code (i.e., the derived functions) and
store them in a data structure (DerivedFunctionSignature and Env)
2. It reads the TOML file and store the metadata in a data structure.
3. It compares the two data structures and check if they are equivalent. If they are not,
it will print the differences.

## Example

Consider this Julia function:

```Julia
@derived v=2 function scc_after_demand_transform(rt::Runtime, scc_id::SCCId)::PhaseResult
    # ...
end
```

A PR will be prevented from being committed/merged if:

- it adds a new derived function that does not exist in `MetadataRegistry.toml`
- if adds or removes one argument of the derived function, e.g., change to
`(rt::Runtime, scc_id::SCCId, x::Int)`
- if changes a version of the derived function, e.g., modify the version to 5
- if it removes a version or adds one, e.g., remove `v=2`

## Programmatically using MetadataUpdater

In a Julia REPL, you can do the following:

```Julia
using MetadataUpdater
env = MetadataUpdater.fetch_metadatainfo()
check(env)
```

The function `fetch_metadatainfo` gathers all the metadata in our codebase in an `Env` object.
The function `check` looks for discrepancies with the `MetadataRegistry.toml` file.

## Limitation

We are aware of the following limitations:
- MetadataUpdater cannot check for the type of arguments and the return type. One reason is
that types cannot be resolved by looking at the source code.
- The presence of a function defined in the `MetadataRegistry.toml` that does not exist in the
source code is not a reason to fail the pre-commit check. 
