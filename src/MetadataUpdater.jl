module MetadataUpdater

using CSTParser: CSTParser, EXPR
using TOML

export update_metadata, check_with_content, check, args_count

struct DerivedFunctionSignature
    name::String
    version::String
    args_count::Integer
end

mutable struct Env
    home_dir::String

    files_count::Integer
    derived_functions::Vector{DerivedFunctionSignature}
    loc::Integer

    Env(home_dir::String) = new(home_dir, 0, DerivedFunctionSignature[], 0)
    Env() = Env("")
end

headof(x::EXPR) = x.head
valof(x::EXPR) = x.val
# kindof(t::Tokens.AbstractToken) = t.kind
parentof(x::EXPR) = x.parent
errorof(x::EXPR) = errorof(x.meta)
errorof(x) = x
haserror(x::EXPR) = hasmeta(x) && haserror(x.meta)
hasmeta(x::EXPR) = x.meta isa LintMeta

function fetch_value(x::EXPR, tag::Symbol, should_fetch_value::Bool=true)
    if headof(x) == tag
        # @info x
        if should_fetch_value
            return x.val
        else # return the AST
            return x
        end
    else
        isnothing(x.args) && return nothing
        for i in 1:length(x.args)
            r = fetch_value(x.args[i], tag, should_fetch_value)
            isnothing(r) || return r
        end
        return nothing
    end
end

function fetch_value(x::Vector{EXPR}, tag::Symbol, should_fetch_value::Bool=true)
    for ast in x
        v = fetch_value(ast, tag, should_fetch_value)
        isnothing(v) || return v
    end
    return nothing
end

# `x` is a top-level entity in a file.
function shallow_walk(x::EXPR, env::Env)
    if x.head in [:module, :file, :block]
        for a in x.args
            shallow_walk(a, env)
        end
        return env
    end

    # Check if it has a documentation in it. If yes, then we recurse
    if headof(x) === :macrocall && x.args[1].head == :globalrefdoc
        v = fetch_value(x.args, :macrocall, false)
        isnothing(v) && return env
        return shallow_walk(v, env)
    end

    # Function is preceded by `@derived`
    if headof(x) === :macrocall
        id = fetch_value(x, :IDENTIFIER)
        if !isnothing(id) && (id == "@derived")

            local version = "nothing"
            #retrieve version number if present
            for a in x.args
                if a.head isa EXPR && a.head.head == :OPERATOR && a.args[1].val == "v"
                    version = a.args[2].val
                end
            end

            function_part_ast = fetch_value(x, :function, false)

            local function_name

            function_name = fetch_value(x, :call, false).args[1].val
            args_count = length(fetch_value(x, :call, false).args) - 2
            if isnothing(function_name)
                # @defined function Foo.bar(...)
                function_name = fetch_value(fetch_value(x, :call, false), :quotenode, false).args[1].val
            end

            sig = DerivedFunctionSignature(function_name, version, args_count)
            push!(env.derived_functions, sig)
        else
            # Function is preceded by `Salsa.@derived`
            id = fetch_value(x, :quotenode, false)
            if !isnothing(id) && (id.args[1].val == "@derived")

                local version = "nothing"
                #retrieve version number if present
                for a in x.args
                    if a.head isa EXPR && a.head.head == :OPERATOR && a.args[1].val == "v"
                        version = a.args[2].val
                    end
                end

                function_part_ast = fetch_value(x, :function, false)

                local function_name

                function_name = fetch_value(x, :call, false).args[1].val
                args_count = length(fetch_value(x, :call, false).args) - 2

                if isnothing(function_name)
                    # @defined function Foo.bar(...)
                    function_name = fetch_value(fetch_value(x, :call, false), :quotenode, false).args[1].val
                end

                sig = DerivedFunctionSignature(function_name, version, args_count)
                push!(env.derived_functions, sig)
            end
        end
    end
end


function update_metadata_string(code::String, env::Env=Env())
    ast = CSTParser.parse(code, true)
    @assert headof(ast) == :file

    for a in ast.args
        shallow_walk(a, env)
    end

    # This may be expensive to do.
    env.loc += length(split(code, "\n"))
    return env
end

function update_metadata(raicode_home::String="."; env::Env=Env(raicode_home), print_summary::Bool=true)
    for (root, dirs, files) in walkdir(raicode_home)
        contains(root, "test") && continue
        contains(root, ".git") && continue
        contains(root, "Salsa/examples") && continue
        contains(root, "Salsa/bench") && continue

        for file in files
            endswith(file, ".jl") || continue
            root_file = joinpath(root, file)
            env.files_count += 1
            # println(root_file) # path to files
            content = open(io->read(io, String), root_file)
            update_metadata_string(content, env)
        end
    end

    if print_summary
        @info "Number of matched files = $(env.files_count)"
        @info "Total loc = $(env.loc)"
        @info "Total derived function = $(length(env.derived_functions))"
    end

    return env
end

##################################################
# Checking

## Main function for checking. Return true if the two arguments are equivalent.
## If some derived functions are missing in the TOML file, it will return false
check(env::Env, filename::String="MetadataRegistry.toml", io::IO=stdout) = check(env, TOML.parsefile(filename), io)

# Useful mostly for debugging purposes
check_with_content(env::Env, toml_content::String, io::IO=stdout) = check(env, TOML.parse(toml_content), io)

function filter_entries(dict::Dict{String, Any})
    cleaned_entries = []
    for bind in collect(dict)
        if !startswith(bind.first, "%")
            push!(cleaned_entries, bind)
        end
    end
    return cleaned_entries
end

function check(found_env::Env, raw_toml_dict::Dict{String, Any}, io::IO=stdout)
    found_derived_functions = found_env.derived_functions

    # Clean gap entries. We do not care about them.
    toml_dict = filter_entries(raw_toml_dict)

    l1 = length(found_derived_functions)
    l2 = length(toml_dict)

    if l1 != l2
        println(io, "In the source code, I found $(l1) derived functions, in TOML file I found $(l2) derived functions")
        println(io, "Number of derived function differs: $(l1) vs $(l2)")
    end

    # LOOK FOR NAMES FOUND IN THE EXTRACTED CODE AND NOT IN THE TOML FILE
    for df in found_derived_functions
        found = false
        for toml_bind in collect(toml_dict)
            if df.name == toml_bind.second["keyspace_name"] &&
                df.args_count == args_count(toml_bind.second["args_type"]) &&
                df.version == toml_bind.second["version"]

                found = true
                break
            elseif df.name == toml_bind.second["keyspace_name"] && df.version != toml_bind.second["version"]
                println(io, "Function named $(df.name) found in source code, but the version differ: $(df.version) vs $(toml_bind.second["version"])")
                return false
            elseif df.name == toml_bind.second["keyspace_name"] && df.args_count != args_count(toml_bind.second["args_type"])
                println(io, "Function named $(df.name) found in source code, but the number of arguments differ: $(df.args_count) vs $(args_count(toml_bind.second["args_type"]))")
                return false
            end
        end
        if !found
            println(io, "Function named $(df.name) found in source code, but not in TOML file")
            return false
        end
    end

    # LOOK FOR NAMES FOUND IN THE TOML FILE AND NOT IN THE EXTRACTED CODE
    for toml_bind in collect(toml_dict)
        found = false
        for df in found_derived_functions
            if df.name == toml_bind.second["keyspace_name"] &&
                df.args_count == args_count(toml_bind.second["args_type"])

                found = true
                break
            end
        end
        if !found
            println(io, "Function named $(toml_bind.second["keyspace_name"]) found in TOML file, but not in source code")
            return false
        end
    end

    return true
end

# Count the number of arguments in the tupple type provided as a string
function args_count(entry::String)
    local nb_of_args = 1
    local index = 1
    local state

    entry == "Tuple{}" && return 0

    # state could be :start, :counting, :skipping
    state = :start
    while (index <= length(entry))
        if state == :start && entry[index] == '{'
            state = :counting

        elseif state == :counting && entry[index] == '}'
            return nb_of_args

        elseif state == :counting && entry[index] == '{'
            state = :skipping

        elseif state == :skipping && entry[index] == '}'
            state = :counting

        elseif state == :counting && entry[index] == ','
            nb_of_args += 1
        end
        index += 1
    end

    return nb_of_args
end

##################################################
# For debugging purposes
# function write_to_file(filename::String="/tmp/df.txt")
#     isfile(filename) && rm(filename)

#     env = update_metadata()
#     open(filename, "w") do io
#         foreach(x -> println(io, string(x)), env.derived_functions)
#     end
#     @info "Extracted derived function signature written to $(filename)"
# end

end