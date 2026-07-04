using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions

result = mainfun_multiarea(
    system=build_ieee_2area_kundur(),
    output_path="res/multi_area/all_vertices_multiarea.txt",
    decoupling_factor=0.1,
)

println("Areas: $(length(result.dynamic_results))")
println("Exported vertices rows: $(size(result.all_vertices, 1))")
