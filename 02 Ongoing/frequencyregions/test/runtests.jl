using Test
using FrequencyRegions
using Plots

ENV["GKSwstype"] = "100"

include("test_regression_fit.jl")
include("test_validation.jl")
include("test_vertices.jl")
include("test_single_area_workflow.jl")
include("test_multiarea_topology.jl")
include("test_multiarea_workflow.jl")
include("test_multiarea_export.jl")
