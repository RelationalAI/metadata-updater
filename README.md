# MetadataUpdater

## Description

MetadataUpdater is a tool to extract metadata from the source code and check if it is
consistent with the TOML file. MetadataUpdater is meant to be used as standalone 
as a [pre-commit](https://pre-commit.com/) hook. Being used by pre-commit means that
MetadataUpdater is transparently and efficiently run by git and by our CI/CD.

MetadataUpdater works as follows:

1. It extracts the metadata from derived functions in our source code and
store them in a data structure (`DerivedFunctionSignature` and `Env`)
2. It reads the TOML file and keeps its recorded metadata in a data structure.
3. It compares the two data structures and checks if they are equivalent. If they are not,
it will print the differences and signal an error to pre-commit.

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

## Manually running MetadataUpdater

There are three ways to run MetadataUpdater:

1. After installing pre-commit in your git repository (`pip install pre-commit` followed by `pre-commit install`), 
simply commit a change in raicode. Any inconsistency between source code and the
`MetadataRegistry.toml` file will prevent the commit from happening.
2. Execute `pre-commit run check-metadata-of-derived-functions --all-files --verbose` in your terminal, while being
in the `raicode` folder.
3. Clone the [RelationalAI/metadata-updater](https://github.com/RelationalAI/metadata-updater) repository and execute
```Julia
using MetadataUpdater
env = MetadataUpdater.fetch_metadatainfo_filenames(["/Users/alexandrebergel/Documents/RAI/raicode3/src/FrontCompiler/eager-maintainers.jl"])
MetadataUpdater.print_summary(env)
check(env, "/Users/alexandrebergel/Documents/RAI/raicode3/MetadataRegistry.toml")
```
<img width="1178" alt="Screenshot 2025-03-18 at 12 51 08" src="https://github.com/user-attachments/assets/388c6acf-1c04-476a-b63a-5951b9e8502c" />

The function `fetch_metadatainfo` gathers all the metadata in our codebase in an `Env` object.
The function `check` looks for discrepancies with the `MetadataRegistry.toml` file.

## Limitation

We are aware of the following limitations:
- MetadataUpdater cannot check for the type of arguments and the return type. One reason is
that types cannot be resolved by looking at the source code.
- The presence of a function defined in the `MetadataRegistry.toml` that does not exist in the
source code is not a reason to fail the pre-commit check. 
