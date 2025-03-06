@testitem "Aqua" begin
    include(joinpath(@__DIR__, "..", "..", "aqua_test_utils.jl"))
    aqua_test_all(MetadataUpdater)
end
