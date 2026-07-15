# mainfun_multiarea.jl
#
# Convenience entry point for running the multi-area frequency security region analysis.
# The actual implementation is located in src/multi_area/mainfun.jl.

if (@__MODULE__) == Main
    using Pkg
    Pkg.activate(@__DIR__)
    using FrequencyRegions
    using Plots

    println("=== Executing multi-area mainfun directly ===")
    result = mainfun_multiarea(
        output_path = "res/multi_area/all_vertices_multiarea.txt",
        decoupling_factor = 0.1,
    )
    println("=== Execution completed successfully ===")
end
