@testitem "Initialization" tags=[:ring1, :unit] begin
    env = MetadataUpdater.Env()
    @test iszero(env.loc)
    @test iszero(env.files_count)
end

@testitem "Basic" begin
    source = """
    @derived v=3 function valid_idb_dependencies_for_def(
        rt::Runtime, path::RelPath, phase::Phase
    )::Immutable{Set{RelPath}}
        return []
    end

    Salsa.@derived v=1 function profile_all_front_specialize(rt::Runtime)::Bool
        return 42
    end

    @derived v=2 function Metadata.layout_for_scc(
        rt::Runtime, scc_id::SCCId, phase::Phase
    )::Vector{Decl}
        return get_scc(rt, scc_id, phase)
    end

    @derived init_weights(s::Runtime) = Tuple(rand(Float64, N_FEATURES))

    @derived v=7 function native_types(db::Runtime, x::Symbol)::Union{Missing,Set{DBTypes}}
        return native_types_uncached(x)
    end

    Salsa.@derived v=1 function is_inline(rt::Runtime, x::DeclId)::Bool
        # Generated decls are never @inline. Asking during TypeInference may lead to a Salsa cycle.
        is_generated(x) && return false
        decl = origin_declaration(rt, x)
        return is_inline(rt, decl)
    end

    @derived v=1 function generated_defs_for_id_normalization(
        rt::Runtime,
        path::RelPath,
    )::PhaseResult
        return 12
    end

    @derived function foo()
        return 12
    end

    @derived cell_is_set(rt::Runtime, id::CellId)::Bool = id in valid_cells(rt)

    @derived v=2 function Metadata.definition_of(rt::Runtime, path::RelPath)::Decl
        return Metadata.definition_of(rt, path, Metadata.last_phase())
    end

    \"\"\"
    valid_dependencies_for_def(
        rt::Runtime,
        path::RelPath,
        phase::Phase,
    )::Immutable{Set{OverloadId}}

    Returns the set of `OverloadId`'s that this definition depends on, including IDBs, EDBs, and
    anonymous relations.

    See also [`valid_idb_dependencies_for_def`](@ref).
    \"\"\"
    @derived v=4 function valid_dependencies_for_def(
        rt::Runtime, path::RelPath, phase::Phase
    )::Immutable{Set{OverloadId}}
        result = Set{OverloadId}()
        function _collect_dependencies(atom::Atom)
            if RAI_BackIR.is_dependency(atom)
                push!(result, decl_id(atom))
            end
            return atom
        end

        function _collect_dependencies(x)
            return x
        end

        RAI_Rewrite.topdown(_collect_dependencies)(definition_of(rt, path, phase))

        return Immutable(result)
    end

    \"\"\"
    a message...
    \"\"\"
    Salsa.@derived v=7 function zork_zork(
        rt::Runtime, path::RelPath, phase::Phase
    )::Immutable{Set{OverloadId}}
        return 42
    end
    """

    ##################################################
    # Top level
    env = MetadataUpdater.update_metadata_string(source)
    @test iszero(env.files_count)
    @test env.loc == length(split(source, "\n"))

    defined_named = ["foo", "cell_is_set", "definition_of",
        "generated_defs_for_id_normalization",
        "is_inline", "native_types", "init_weights", "layout_for_scc",
        "profile_all_front_specialize", "valid_idb_dependencies_for_def",
        "valid_dependencies_for_def", "zork_zork"]
    for n in defined_named
        @test any(f->f.name == n, env.derived_functions)
    end
    @test length(env.derived_functions) == length(defined_named)

    ##################################################
    # Check particular functions
    # f = env.derived_functions[end]
    f = first(Iterators.filter(x -> x.name == "valid_dependencies_for_def", env.derived_functions))
    @test f.name == "valid_dependencies_for_def"
    @test f.args_count == 2
    @test f.version == "4"

    # f = env.derived_functions[end]
    f = first(Iterators.filter(x -> x.name == "zork_zork", env.derived_functions))
    @test f.name == "zork_zork"
    @test f.args_count == 2
    @test f.version == "7"

    ##################################################
    # Within a module
    source = "module FooBar\n" * source * "\nend\n"
    env = MetadataUpdater.update_metadata_string(source)
    @test iszero(env.files_count)
    @test env.loc == length(split(source, "\n"))

    for n in defined_named
        @test any(f->f.name == n, env.derived_functions)
    end
    @test length(env.derived_functions) == length(defined_named)
end

# @testitem "Basic2" tags=[:ring1, :unit] begin
#     # file_to_analyze = joinpath(pwd(), "packages", "MetadataUpdater", "src", "MetadataUpdater.jl")
#     file_to_analyze = "basic_tests.jl"
#     isfile(file_to_analyze) || return
#     env = MetadataUpdater.update_metadata(file_to_analyze; print_summary=false)
#     @test env.files_count == 1
#     @test isempty(env.derived_functions)
# end

@testitem "Number of arguments" tags=[:ring1, :unit] begin
    @test args_count("Tuple{}") == 0
    @test args_count("Tuple{String}") == 1
    @test args_count("Tuple{RAICode.DependencyGraph.SCCId, RAICode.Metadata.Phase}") == 2
    @test args_count("Tuple{Core.Symbol, RAICode.FrontCompiler.After{<:Union{RAICode.FrontCompiler.CompilePhaseNaming, RAICode.FrontCompiler.CompilePhaseSpecialize}}}") == 2
end