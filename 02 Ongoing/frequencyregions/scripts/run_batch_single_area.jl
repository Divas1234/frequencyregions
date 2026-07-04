using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions
using Plots

const DROOP_PARAMETERS = collect(range(33, 40; length=20))

function main()
    println("Frequency Regions - batch single-area analysis")

    controller_cfg = default_controller_config()
    comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)
    combined_plot, vertices_matrix = execute_batch_workflow(DROOP_PARAMETERS, comp_cfg, controller_cfg)

    project_root = normpath(joinpath(@__DIR__, ".."))
    mkpath(joinpath(project_root, "fig", "single_area"))
    mkpath(joinpath(project_root, "res", "single_area"))

    display(combined_plot)
    Plots.savefig(combined_plot, joinpath(project_root, "fig", "single_area", "batch_output_plot.png"))
    Plots.savefig(combined_plot, joinpath(project_root, "fig", "single_area", "batch_output_plot.pdf"))
    write_vertices_to_file(vertices_matrix, project_root, OUTPUT_REL_PATH)

    println("Processed $(length(DROOP_PARAMETERS)) droop values.")
    println("Exported $(size(vertices_matrix, 1)) vertices to $(joinpath(project_root, OUTPUT_REL_PATH)).")

    return combined_plot, vertices_matrix
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
