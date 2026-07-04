using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions
using Plots

result = mainfun(33.0; save_vertices=true)

mkpath(joinpath(@__DIR__, "..", "fig", "single_area"))
Plots.savefig(result.plot, joinpath(@__DIR__, "..", "fig", "single_area", "single_area.png"))

println(get_workflow_summary(result))
