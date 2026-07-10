"""
    multi_area_runner.jl

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
  :results (Vector{AreaResult}), :all_vertices (Matrix{Float64})
"""
function run_multiarea_analysis(;
    system::Union{MultiAreaSystem,Nothing}=nothing,
    damping_range::AbstractRange=2:0.25:15,
    min_damping::Float64=2.5,
    max_damping::Float64=12.0,
    flag_converter::Int64=0,
    output_path::String="res/all_vertices_multiarea.txt",
    decoupling_factor::Float64=0.1,
)
    sys = isnothing(system) ? build_ieee_2area_kundur() : system

    println("="^60)
    println("  Multi-Area Frequency Security Region Analysis")
    println("  Method: Decoupled Approximation (Option A)")
    println("  Areas: $(length(sys.areas)), Tie-lines: $(length(sys.tie_lines))")
    println("="^60)

    for area in sys.areas
        println("  Area $(area.id): H=$(area.initial_inertia), R=1/$(round(1/area.droop, digits=3)), ΔP=$(area.power_deviation)")
    end
    for tl in sys.tie_lines
        println("  Tie-line: Area$(tl.from_area) ↔ Area$(tl.to_area), T=$(tl.synchronizing_coeff), Capacity=$(tl.capacity)")
    end
    println("="^60)

    controller_config_dict = converter_formming_configuations()
    controller_cfg = ControllerConfig(
        controller_config_dict["VSM"]["control_parameters"],
        controller_config_dict["Droop"]["control_parameters"],
    )

    comp_cfg = create_computation_config(damping_range, min_damping, max_damping, flag_converter)

    println("\n  [Decoupling factor: $decoupling_factor]")
    results = execute_multiarea_workflow(sys, comp_cfg, controller_cfg, factor=decoupling_factor)
    print_multiarea_summary(results)

    all_vertices = collect_all_vertices(results)

    p_comp = plot_multiarea_comparison(results, comp_cfg)
    p_overlay = plot_feasible_region_overlay(results, comp_cfg)
    p_summary = plot_combined_summary(results, comp_cfg)

    if !isempty(all_vertices)
        write_multiarea_vertices_to_file(all_vertices, pwd(), output_path)
    end

    return (
        comparison_plot=p_comp,
        overlay_plot=p_overlay,
        summary_plot=p_summary,
        results=results,
        all_vertices=all_vertices,
    )
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
