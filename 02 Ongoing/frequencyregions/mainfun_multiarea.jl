if (@__MODULE__) == Main
    using Pkg
    Pkg.activate(@__DIR__)
    using FrequencyRegions
    using Plots
    import FrequencyRegions: print_dynamic_multiarea_summary,
        plot_multiarea_comparison,
        plot_feasible_region_overlay,
        plot_combined_summary,
        plot_sharing_capacity_impact,
        plot_sharing_stiffness_impact
end
##
"""
    multi_area/mainfun.jl

English: Top-level entry point for multi-area frequency security region analysis.
Orchestrates network loading → decoupled computation → dynamic coupled simulation → visualization → export.
Chinese: 多区域频率安全区域分析的顶层入口点。
协调网架数据加载 → 解耦计算 (方案 A) → 动态耦合模拟 (方案 B) → 可视化绘图 → 结果导出。
"""

"""
    save_plot_if_present(plot_obj, path::String)

English: Saves the Plots.jl object to the specified path after ensuring the parent directory exists.
Chinese: 在确保父级目录存在的前提下，将 Plots.jl 绘图对象保存到指定路径。
"""
function save_plot_if_present(plot_obj, path::String)
    if !isnothing(plot_obj)
        mkpath(dirname(path))
        Plots.savefig(plot_obj, path)
        println("Saved: $path")
    end
end

"""
    run_multiarea_analysis(; kwargs...) -> NamedTuple

English: Main entry point for executing multi-area frequency security region analysis.
Computes both Decoupled Approximation (Option A) and Dynamic Mutual Assistance (Option B).
Chinese: 运行多区域频率安全区域分析的主入口函数。
同时计算并对比解耦近似方法（方案 A）以及基于物理模型的动态相互支援方法（方案 B）。

# Keyword arguments (可选关键字参数)
- `system::MultiAreaSystem`: Pre-built system struct (if omitted, uses built-in IEEE 2-area Kundur)
                             预置的多区域系统结构体（若缺失，则默认加载 Kundur 双区系统）
- `damping_range::AbstractRange`: Damping range to sweep (default: 2:0.25:15) (阻尼参数扫频范围，默认 2:0.25:15)
- `min_damping::Float64`: Min damping for vertex extraction (default: 2.5) (多边形顶点提取的阻尼下界，默认 2.5)
- `max_damping::Float64`: Max damping for vertex extraction (default: 12.0) (多边形顶点提取的阻尼上界，默认 12.0)
- `flag_converter::Int64`: 0=traditional (grid-following), 1=modern (grid-forming) (default: 0) (换流器模型标志)
- `output_path::String`: File path for exporting all feasible vertices (default: "res/multi_area/all_vertices_multiarea.txt")
                         导出的可行域顶点结果文件路径
- `decoupling_factor::Float64`: Decoupling factor for Option A (default: 0.1) (方案 A 阻尼和容量耦合安全系数，默认 0.1)

# Returns (返回)
- NamedTuple containing results for both methods, all plotting objects, and exported vertices matrix.
  包含两种方法的计算结果、所有的绘图对象以及导出的顶点矩阵的 NamedTuple。
"""
##
function run_multiarea_analysis(;
    system::Union{MultiAreaSystem,Nothing}=nothing,
    damping_range::AbstractRange=2:0.25:15,
    min_damping::Float64=2.5,
    max_damping::Float64=12.0,
    flag_converter::Int64=0,
    output_path::String="res/multi_area/all_vertices_multiarea.txt",
    decoupling_factor::Float64=0.1,
)
    println("\n=== [Stage 1/6] Loading network topology and configuration parameters ===")
    # Load system: default to classic IEEE 2-area Kundur (加载电网拓扑，默认双区系统)
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

    # Setup configurations (控制器参数与计算参数初始化)
    controller_config_dict = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config_dict["VSM"]["control_parameters"],
        controller_config_dict["Droop"]["control_parameters"],
    )

    comp_cfg = create_computation_config(damping_range, min_damping, max_damping, flag_converter)

    println("\n=== [Stage 2/6] Running Option A: Decoupled Approximation workflow ===")
    # 1. Run Decoupled Option A (Isolated & Interconnected / 运行解耦方案 A)
    println("\n>>> Running Decoupled Isolated (Option A)...")
    results_decoupled_isolated = execute_multiarea_workflow(sys, comp_cfg, controller_cfg, factor=0.0)

    println("\n>>> Running Decoupled Interconnected (Option A)...")
    results_decoupled = execute_multiarea_workflow(sys, comp_cfg, controller_cfg, factor=decoupling_factor)
    print_multiarea_summary(results_decoupled)

    println("\n=== [Stage 3/6] Running Option B: Dynamic Coupled Mutual Assistance Simulation workflow ===")
    # 2. Run Dynamic Option B (Isolated & Interconnected / 运行耦合仿真方案 B)
    println("\n>>> Running Dynamic Isolated (Option B)...")
    # Isolated means synchronizing coefficient exists but tie capacity is zero (孤立相当于联络线极限为0)
    sys_isolated = MultiAreaSystem(sys.areas, [TieLine(tl.from_area, tl.to_area, tl.synchronizing_coeff, 0.0) for tl in sys.tie_lines])
    results_dynamic_isolated = execute_dynamic_multiarea_workflow(sys_isolated, comp_cfg, controller_cfg)

    println("\n>>> Running Dynamic Interconnected (Option B)...")
    results_dynamic = execute_dynamic_multiarea_workflow(sys, comp_cfg, controller_cfg)
    print_dynamic_multiarea_summary(results_dynamic)

    println("\n=== [Stage 4/6] Exporting physical coupled safety region boundary vertices ===")
    # Collect vertices for Option B (dynamic) since it represents the true physical boundary
    # 收集方案 B (物理耦合) 下的顶点数据，代表了实际动态互联物理边界
    all_vertices = collect_all_vertices(results_dynamic)

    # Export Vertices (导出可行域顶点到 txt 文件)
    if !isempty(all_vertices)
        write_multiarea_vertices_to_file(all_vertices, pwd(), output_path)
    else
        println("Warning: No vertices collected. Skipping export.")
    end

    println("\n=== [Stage 5/6] Generating comparison, overlay, and parameter sensitivity plots ===")
    # 3. Plot results (绘制所有 analysis 曲线图)
    # Plots for Decoupled Option A (解耦方案 A 绘图)
    p_comp = plot_multiarea_comparison(results_decoupled_isolated, results_decoupled, sys, comp_cfg)
    p_overlay = plot_feasible_region_overlay(results_decoupled, comp_cfg)
    p_summary = plot_combined_summary(results_decoupled_isolated, results_decoupled, sys, comp_cfg)

    # Plots for Dynamic Option B (耦合动态方案 B 绘图)
    p_comp_dyn = plot_multiarea_comparison(results_dynamic_isolated, results_dynamic, sys, comp_cfg)
    p_overlay_dyn = plot_feasible_region_overlay(results_dynamic, comp_cfg)

    # Parameter impact plots (specifically studying tie-line parameters on Area 1)
    # 参数灵敏度影响绘图（以区域1有功扰动下联络线容量与刚度的影响为例）
    p_capacity_impact = plot_sharing_capacity_impact(1, sys, comp_cfg, controller_cfg)
    p_stiffness_impact = plot_sharing_stiffness_impact(1, sys, comp_cfg, controller_cfg)

    println("\n=== [Stage 6/6] Saving all plot files and printing execution summary ===")
    # 4. Save plots to files (将图形保存到文件)
    save_plot_if_present(p_comp, "fig/multi_area/multiarea_comparison.pdf")
    save_plot_if_present(p_overlay, "fig/multi_area/multiarea_overlay.pdf")
    save_plot_if_present(p_summary, "fig/multi_area/multiarea_summary.pdf")

    save_plot_if_present(p_comp, "fig/multi_area/multiarea_factor$(decoupling_factor)_comparison.pdf")
    save_plot_if_present(p_overlay, "fig/multi_area/multiarea_factor$(decoupling_factor)_overlay.pdf")

    save_plot_if_present(p_comp_dyn, "fig/multi_area/multiarea_comparison_dynamic.pdf")
    save_plot_if_present(p_overlay_dyn, "fig/multi_area/multiarea_overlay_dynamic.pdf")
    save_plot_if_present(p_capacity_impact, "fig/multi_area/multiarea_capacity_impact.pdf")
    save_plot_if_present(p_stiffness_impact, "fig/multi_area/multiarea_stiffness_impact.pdf")

    println("\n=== Multi-area summary ===")
    println("Areas: $(length(results_dynamic))")
    println("Exported vertices rows: $(size(all_vertices, 1))")
    println("Vertices file: $output_path")
    println("Capacity impact plot: fig/multi_area/multiarea_capacity_impact.pdf")
    println("Stiffness impact plot: fig/multi_area/multiarea_stiffness_impact.pdf")
    println("=== Done ===")

    if isinteractive() && !isnothing(p_comp_dyn)
        println("=== Displaying dynamic comparison plot in REPL ===")
        display(p_comp_dyn)
    end

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

English: Writes multi-area vertices to a tab-separated text file containing: area_id, droop, damping, inertia.
Chinese: 将多区域可行域顶点写入以制表符分隔的文本文件中，格式为: area_id, 下垂系数, 阻尼系数, 惯性常数。
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

if (@__MODULE__) == Main
    println("=== Executing multi-area mainfun directly ===")
    result = mainfun_multiarea(
        output_path="res/multi_area/all_vertices_multiarea.txt",
        decoupling_factor=0.1,
    )
    println("=== Execution completed successfully ===")
end
