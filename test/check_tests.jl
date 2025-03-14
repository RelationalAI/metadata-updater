@testset "In a module" begin
    source = """
    module FooBar
    @derived function foo(rt)
        return 12
    end

    @derived v = 2 function bar(rt, x)
        return 12
    end

    @derived v = 10 function zork(rt, x, y, z)
        return 12
    end
    end
    """
    env = MetadataUpdater.fetch_metadatainfo_sourcecode(source)

    @testset "Sanity check" begin
        defined_named = ["foo", "bar", "zork"]

        for n in defined_named
            @test any(f->f.name == n, env.derived_functions)
        end

        @test env.derived_functions[1].name == "foo"
        @test env.derived_functions[1].args_count == 0
        @test env.derived_functions[1].version == "nothing"
        @test env.derived_functions[2].name == "bar"
        @test env.derived_functions[2].args_count == 1
        @test env.derived_functions[2].version == "2"
        @test env.derived_functions[3].name == "zork"
        @test env.derived_functions[3].args_count == 3
        @test env.derived_functions[3].version == "10"
    end

    @testset "All good, no errors" begin
        toml_content = """
        [foo]
        args_type = "Tuple{}"
        keyspace_name = "foo"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "nothing"

        [bar]
        args_type = "Tuple{String}"
        keyspace_name = "bar"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "2"

        [zork]
        args_type = "Tuple{String, String, String}"
        keyspace_name = "zork"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "10"
        """

        # No error
        io = IOBuffer()
        @test check_with_content(env, toml_content, io)
    end

    @testset "Args count mismatch 1" begin
        toml_content = """
        [foo]
        args_type = "Tuple{String}"
        keyspace_name = "foo"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "nothing"

        [bar]
        args_type = "Tuple{String}"
        keyspace_name = "bar"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "2"

        [zork]
        args_type = "Tuple{String, String, String}"
        keyspace_name = "zork"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "10"
        """

        # No error
        io = IOBuffer()
        @test !check_with_content(env, toml_content, io)
        @test endswith(String(take!(io)), "Function named `foo` found in source code with a different number of arguments than those persisted to the file MetadataRegistry.toml: 0 vs 1\n")
    end

    @testset "Args count mismatch 2" begin
        toml_content = """
        [foo]
        args_type = "Tuple{String}"
        keyspace_name = "foo"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "nothing"

        [bar]
        args_type = "Tuple{String}"
        keyspace_name = "bar"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "2"

        [zork]
        args_type = "Tuple{String, String}"
        keyspace_name = "zork"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "10"
        """

        # No error
        io = IOBuffer()
        @test !check_with_content(env, toml_content, io)
        @test endswith(String(take!(io)), "Function named `foo` found in source code with a different number of arguments than those persisted to the file MetadataRegistry.toml: 0 vs 1\n")
    end

    @testset "Function found in source code, but not in toml" begin
        toml_content = """
        [foo]
        args_type = "Tuple{}"
        keyspace_name = "foo"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "nothing"

        [bar]
        args_type = "Tuple{String}"
        keyspace_name = "bar"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "2"
        """

        # No error
        io = IOBuffer()
        @test !check_with_content(env, toml_content, io)
        @test endswith(String(take!(io)), "Function named zork found in source code, but not in TOML file\n")
    end

    # @testset "Function not found in source code" begin
    #     toml_content = """
    #     [foo]
    #     args_type = "Tuple{}"
    #     keyspace_name = "foo"
    #     return_type = "RAICode.FrontCompiler.PhaseResult"
    #     version = "nothing"

    #     [bar]
    #     args_type = "Tuple{String}"
    #     keyspace_name = "bar"
    #     return_type = "RAICode.FrontCompiler.PhaseResult"
    #     version = "2"

    #     [zork]
    #     args_type = "Tuple{String, String, String}"
    #     keyspace_name = "zork"
    #     return_type = "RAICode.FrontCompiler.PhaseResult"
    #     version = "10"

    #     [zork_not_found]
    #     args_type = "Tuple{String, String}"
    #     keyspace_name = "zork_not_found"
    #     return_type = "RAICode.FrontCompiler.PhaseResult"
    #     version = "12"
    #     """

    #     # No error
    #     io = IOBuffer()
    #     @test !check_with_content(env, toml_content, io)
    #     @test endswith(String(take!(io)), "Function named zork_not_found found in TOML file, but not in source code\n")
    # end

    @testset "Incorrect version number" begin
        toml_content = """
        [foo]
        args_type = "Tuple{}"
        keyspace_name = "foo"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "nothing"

        [bar]
        args_type = "Tuple{String}"
        keyspace_name = "bar"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "2"

        [zork]
        args_type = "Tuple{String, String, String}"
        keyspace_name = "zork"
        return_type = "RAICode.FrontCompiler.PhaseResult"
        version = "20"
        """

        # Incorrect version number
        io = IOBuffer()
        @test !check_with_content(env, toml_content, io)
        @test endswith(String(take!(io)), "Function named `zork` found in source code with a different version from that persisted to the file TOML file: 10 vs 20\n")
    end

end