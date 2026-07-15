# mainfun.jl
#
# Convenience entry point for running the single-area frequency security region analysis.
# The actual implementation is located in src/single_area/mainfun.jl.

if (@__MODULE__) == Main
    using Pkg
    Pkg.activate(@__DIR__)
    using FrequencyRegions
    using Plots

    println("=== Executing single-area mainfun directly ===")
    result = mainfun(33.0; save_vertices = true, save_plot = true)
    println("=== Execution completed successfully ===")
end
