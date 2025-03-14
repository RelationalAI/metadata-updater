@testset "Initialization"  begin
    env = MetadataUpdater.Env()
    @test iszero(env.loc)
    @test iszero(env.files_count)
end

@testset "Basic" begin
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
    env = MetadataUpdater.fetch_metadatainfo_sourcecode(source)
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
    env = MetadataUpdater.fetch_metadatainfo_sourcecode(source)
    @test iszero(env.files_count)
    @test env.loc == length(split(source, "\n"))

    for n in defined_named
        @test any(f->f.name == n, env.derived_functions)
    end
    @test length(env.derived_functions) == length(defined_named)
end

@testset "Multiple files" begin
    file1_source = """
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
    """

    file2_source = """
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

    mktempdir() do temp_dir
        file1_path = joinpath(temp_dir, "file1.jl");
        file2_path = joinpath(temp_dir, "file2.jl");

        open(file1_path, "w") do file1_io
            write(file1_io, file1_source)
            flush(file1_io)
            open(file2_path, "w") do file2_io
                write(file2_io, file2_source)
                flush(file2_io)

                ##################################################
                # Top level
                env = MetadataUpdater.fetch_metadatainfo_filenames([file1_path, file2_path])
                @test env.files_count == 2
                @test env.loc == length(split(file1_source, "\n")) + length(split(file2_source, "\n"))

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
            end
        end
    end
end


@testset "Number of arguments" begin
    @test args_count("Tuple{}") == 0
    @test args_count("Tuple{String}") == 1
    @test args_count("Tuple{RAICode.DependencyGraph.SCCId, RAICode.Metadata.Phase}") == 2
    @test args_count("Tuple{Core.Symbol, RAICode.FrontCompiler.After{<:Union{RAICode.FrontCompiler.CompilePhaseNaming, RAICode.FrontCompiler.CompilePhaseSpecialize}}}") == 2
end

@testset "File should be skipped" begin
    @test MetadataUpdater.should_file_name_be_skipped("test/basic_tests.jl")
    @test MetadataUpdater.should_file_name_be_skipped("test/basic_tests.txt")
    @test MetadataUpdater.should_file_name_be_skipped("test/")
    @test MetadataUpdater.should_file_name_be_skipped(".git/foo.jl")
    @test !MetadataUpdater.should_file_name_be_skipped("src/foo.jl")
    @test !MetadataUpdater.should_file_name_be_skipped("packages/Foo/src/foo.jl")
    @test MetadataUpdater.should_file_name_be_skipped("packages/Foo/src/foo.txt")
    @test MetadataUpdater.should_file_name_be_skipped("test/Results/snapshot-testing/expected/string/2.arrow")
end