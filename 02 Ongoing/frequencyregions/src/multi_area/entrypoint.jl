"""
    multi_area/entrypoint.jl

Top-level entry point for multi-area frequency security region analysis.
Orchestrates network loading → decoupled computation → visualization → export.
"""

"""
    run_multiarea_analysis(; kwargs...) -> NamedTuple

Main entry point for multi-area frequency security analysis.

# Keyword arguments
- `system::MultiAreaSystem`: Pre-built system (if omitted, uses built-in 2-area)
- `damping_range::AbstractRange`: Damping range for computation (default: 2:0.25:15)
- `min_damping::Float64`: Min damping for vertex extraction (default: 2.5)
- `max_damping::Float64`: Max damping for vertex extraction (default: 12.0)
- `flag_converter::Int64`: 0=traditional, 1=modern (default: 0)
- `output_path::String`: File path for vertex export (default: "res/all_vertices_multiarea.txt")

# Returns
- NamedTuple with fields: :comparison_plot, :overlay_plot, :summary_plot,
  :results (Vector{AreaResult}), :all_vertices (Matrix{Float64})"""
function save_plot_if_present(plot_obj, path::String)
    if !isnothing(plot_obj)
        mkpath(dirname(path))
        Plots.savefig(plot_obj, path)
        println("Saved: $path")
    end
end

function run_multiarea_analysis(;
    system::Union{MultiAreaSystem,Nothing}=nothing,
    damping_range::AbstractRange=2:0.25:15,
    min_damping::Float64=2.5,
    max_damping::Float64=12.0,
    flag_converter::Int64=0,
    output_path::String="res/multi_area/all_vertices_multiarea.txt",
    decoupling_factor::Float64=0.1,
)
    sys = isnothing(system) ? build_ieee_2area_kundur() : system

    println("="^60)
    println("  Multi-Area Frequency Security Region Analysis")
    println("  Method: Decoupled (Option A) & Dynamic (Option B)")
    println("  Areas: $(length(sys.areas)), Tie-lines: $(length(sys.tie_lines))")
    println("="^60)

    for area in sys.areas
        println("  Area $(area.id): H=$(area.initial_inertia), R=1/$(round(1/area.droop, digits=3)), ΔP=$(area.power_deviation)")
    end
    for tl in sys.tie_lines
        println("  Tie-line: Area$(tl.from_area) ↔ Area$(tl.to_area), T=$(tl.synchronizing_coeff), Capacity=$(tl.capacity)")
    end
    println("="^60)

    controller_config_dict = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config_dict["VSM"]["control_parameters"],
        controller_config_dict["Droop"]["control_parameters"],
    )

    comp_cfg = create_computation_config(damping_range, min_damping, max_damping, flag_converter)

    # 1. Run Decoupled Option A (Isolated & Interconnected)
    println("\n>>> Running Decoupled Isolated (Option A)...")
    results_decoupled_isolated = execute_multiarea_workflow(sys, comp_cfg, controller_cfg, factor=0.0)

    println("\n>>> Running Decoupled Interconnected (Option A)...")
    results_decoupled = execute_multiarea_workflow(sys, comp_cfg, controller_cfg, factor=decoupling_factor)
    print_multiarea_summary(results_decoupled)

    # 2. Run Dynamic Option B (Isolated & Interconnected)
    println("\n>>> Running Dynamic Isolated (Option B)...")
    sys_isolated = MultiAreaSystem(sys.areas, [TieLine(tl.from_area, tl.to_area, tl.synchronizing_coeff, 0.0) for tl in sys.tie_lines])
    results_dynamic_isolated = execute_dynamic_multiarea_workflow(sys_isolated, comp_cfg, controller_cfg)

    println("\n>>> Running Dynamic Interconnected (Option B)...")
    results_dynamic = execute_dynamic_multiarea_workflow(sys, comp_cfg, controller_cfg)
    print_dynamic_multiarea_summary(results_dynamic)

    # Collect vertices for Option B (dynamic) since it represents the true physical boundary
    all_vertices = collect_all_vertices(results_dynamic)

    # Plot results
    # For Decoupled Option A
    p_comp = plot_multiarea_comparison(results_decoupled_isolated, results_decoupled, sys, comp_cfg)
    p_overlay = plot_feasible_region_overlay(results_decoupled, comp_cfg)
    p_summary = plot_combined_summary(results_decoupled_isolated, results_decoupled, sys, comp_cfg)

    # For Dynamic Option B
    p_comp_dyn = plot_multiarea_comparison(results_dynamic_isolated, results_dynamic, sys, comp_cfg)
    p_overlay_dyn = plot_feasible_region_overlay(results_dynamic, comp_cfg)

    # Impact plots (specifically studying tie-line parameters on Area 1)
    p_capacity_impact = plot_sharing_capacity_impact(1, sys, comp_cfg, controller_cfg)
    p_stiffness_impact = plot_sharing_stiffness_impact(1, sys, comp_cfg, controller_cfg)

    # Save plots
    save_plot_if_present(p_comp, "fig/multi_area/multiarea_comparison.pdf")
    save_plot_if_present(p_overlay, "fig/multi_area/multiarea_overlay.pdf")
    save_plot_if_present(p_summary, "fig/multi_area/multiarea_summary.pdf")

    save_plot_if_present(p_comp, "fig/multi_area/multiarea_factor$(decoupling_factor)_comparison.pdf")
    save_plot_if_present(p_overlay, "fig/multi_area/multiarea_factor$(decoupling_factor)_overlay.pdf")

    save_plot_if_present(p_comp_dyn, "fig/multi_area/multiarea_comparison_dynamic.pdf")
    save_plot_if_present(p_overlay_dyn, "fig/multi_area/multiarea_overlay_dynamic.pdf")
    save_plot_if_present(p_capacity_impact, "fig/multi_area/multiarea_capacity_impact.pdf")
    save_plot_if_present(p_stiffness_impact, "fig/multi_area/multiarea_stiffness_impact.pdf")

    if !isempty(all_vertices)
        write_multiarea_vertices_to_file(all_vertices, pwd(), output_path)
    end

    println("\n=== Multi-area summary ===")
    println("Areas: $(length(results_dynamic))")
    println("Exported vertices rows: $(size(all_vertices, 1))")
    println("Vertices file: $output_path")
    println("Capacity impact plot: fig/multi_area/multiarea_capacity_impact.pdf")
    println("Stiffness impact plot: fig/multi_area/multiarea_stiffness_impact.pdf")
    println("=== Done ===")

    return (
        results=results_dynamic,
        decoupled_results=results_decoupled,
        dynamic_results=results_dynamic,
        comparison_plot=p_comp,
        overlay_plot=p_overlay,
        summary_plot=p_summary,
        comparison_plot_dyn=p_comp_dyn,
        overlay_plot_dyn=p_overlay_dyn,
        capacity_impact_plot=p_capacity_impact,
        stiffness_impact_plot=p_stiffness_impact,
        all_vertices=all_vertices,
    )
end

function mainfun_multiarea(; kwargs...)
    return run_multiarea_analysis(; kwargs...)
end


"""
    write_multiarea_vertices_to_file(all_vertices::Matrix, base_path::String, rel_path::String)

Writes multi-area vertices to file (area_id, droop, damping, inertia).
"""
function write_multiarea_vertices_to_file(all_vertices::Matrix, base_path::String, rel_path::String)
    output_dir = dirname(joinpath(base_path, rel_path))
    if !isdir(output_dir)
        mkpath(output_dir)
    end

    open(joinpath(base_path, rel_path), "w") do io
        println(io, "# area_id\tdroop\tdamping\tinertia")
        for row in eachrow(all_vertices)
            println(io, join(row, "\t"))
        end
    end

    println("Vertices saved to: $(joinpath(base_path, rel_path))")
end
