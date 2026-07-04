using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions
using Plots

const DROOP_PARAMETERS = collect(range(33, 40; length=20))

function build_supportset_plot(droop_parameter)
    p = generate_inertia_damping_figure(Float64(droop_parameter))
    _, sub_vertices = get_inertiatodamping_functions(droop_parameter)

    x_coords = [v[2] for v in sub_vertices]
    y_coords = [v[3] for v in sub_vertices]

    Plots.plot!(
        p,
        x_coords,
        y_coords;
        seriestype=:shape,
        fillalpha=0.2,
        fillcolor=:red,
        label="Feasible Region",
    )

    return p, sub_vertices
end

project_root = normpath(joinpath(@__DIR__, ".."))
mkpath(joinpath(project_root, "fig", "single_area"))

p1, _ = build_supportset_plot(DROOP_PARAMETERS[1])
p2, _ = build_supportset_plot(DROOP_PARAMETERS[4])
p3, _ = build_supportset_plot(DROOP_PARAMETERS[6])
p4, _ = build_supportset_plot(DROOP_PARAMETERS[10])

fig = Plots.plot(p1, p2, p3, p4; layout=(2, 2), size=(400, 400), dpi=400, legend=false)

Plots.savefig(fig, joinpath(project_root, "fig", "single_area", "inertia_damping_feasible_region.png"))
Plots.savefig(fig, joinpath(project_root, "fig", "single_area", "inertia_damping_feasible_region.pdf"))
