if (@__MODULE__) == Main
    using Pkg
    Pkg.activate(joinpath(@__DIR__, "..", ".."))
    using FrequencyRegions
    using Plots
end

"""
    mainfun(droop::Real=33.0; save_vertices::Bool=false, output_path::String=OUTPUT_REL_PATH) -> ComputationResult

English: Top-level entry point for single-area frequency security region analysis.
Runs the workflow to calculate the frequency security boundary and feasible region vertices.
Chinese: 单区域频率安全区域分析的顶层入口函数。
运行工作流以计算频率安全边界和可行域顶点。

# Arguments (参数)
- `droop`: Governor regulation droop parameter (调速器下垂系数)
- `save_vertices`: Set true to export the vertices to a file (设置为 true 将顶点导出到文件)
- `output_path`: Path to save the exported vertices file (导出的顶点文件保存路径)
- `verbose`: Set true to print workflow summary to the console (设置为 true 将打印工作流摘要结果)
- `show_plot`: Set true to display the plot interactively (设置为 true 将在交互环境下显示曲线图)
- `save_plot`: Set true to save the plot to a file (设置为 true 将图表保存为文件)
- `plot_path`: Destination path for the saved plot (保存图表的目标文件路径)
"""
function mainfun(
    droop::Real=33.0;
    save_vertices::Bool=false,
    output_path::String=OUTPUT_REL_PATH,
    verbose::Bool=true,
    show_plot::Bool=true,
    save_plot::Bool=false,
    plot_path::String="fig/single_area/single_area.png"
)
    if verbose
        println("\n=== [Stage 1/5] Initializing Single-Area configurations (droop = $droop) ===")
    end

    if verbose
        println("=== [Stage 2/5] Running single-area frequency security workflow ===")
    end
    result = execute_workflow(
        Float64(droop),
        create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0),
        default_controller_config(),
    )

    if save_vertices
        if verbose
            println("=== [Stage 3/5] Exporting feasible region vertices to file ===")
        end
        matrix = vertices_to_matrix([result.vertices])
        write_vertices_to_file(matrix, pwd(), output_path)
    else
        if verbose
            println("=== [Stage 3/5] Skipping vertices file export (save_vertices = false) ===")
        end
    end

    if verbose
        println("=== [Stage 4/5] Workflow completed. Printing results summary ===")
        println(get_workflow_summary(result))
    end

    if save_plot
        if verbose
            println("=== [Stage 5/5] Saving visualization plots to $plot_path ===")
        end
        mkpath(dirname(plot_path))
        
        # Save main region plot in both PNG and PDF formats
        png_path = plot_path
        pdf_path = replace(plot_path, ".png" => ".pdf")
        Plots.savefig(result.plot, png_path)
        Plots.savefig(result.plot, pdf_path)
        
        # Reconstruct state to generate time-domain verification trajectories plot
        config = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)
        controller_cfg = default_controller_config()
        system_params = create_system_parameters(config.flag_converter)
        state = WorkflowState(controller_cfg, system_params, config)
        state.system_params = SystemParameters(
            system_params.initial_inertia,
            system_params.factorial_coefficient,
            system_params.time_constant,
            Float64(droop),
            system_params.rocof_threshold,
            system_params.nadir_threshold,
            system_params.power_deviation
        )
        compute_inertia_bounds(state)
        state.fitting_parameters = result.fitting_parameters
        
        min_inertia, max_inertia = estimate_inertia_limits(
            state.system_params.rocof_threshold,
            state.system_params.power_deviation,
            state.computation_config.damping_range,
            state.system_params.factorial_coefficient,
            state.system_params.time_constant,
            state.system_params.droop
        )
        
        verify_plot = plot_single_area_verification_trajectories(state, min_inertia, maximum(max_inertia))
        verify_png_path = joinpath(dirname(plot_path), "single_area_verification_trajectories.png")
        verify_pdf_path = joinpath(dirname(plot_path), "single_area_verification_trajectories.pdf")
        Plots.savefig(verify_plot, verify_png_path)
        Plots.savefig(verify_plot, verify_pdf_path)
        
        if verbose
            println("Saved single-area plot to: ", png_path, " and ", pdf_path)
            println("Saved verification trajectories to: ", verify_png_path, " and ", verify_pdf_path)
        end
    else
        if verbose
            println("=== [Stage 5/5] Skipping plot save (save_plot = false) ===")
        end
    end

    if show_plot && isinteractive()
        println("=== Displaying safety boundary plot in REPL ===")
        display(result.plot)
    end

    return result
end

"""
    get_inertiatodamping_functions(droop_parameters::Real) -> Tuple

English: Legacy wrapper to compute single-area safety boundary plotting and vertices.
Chinese: 兼容旧版调用的包装函数，计算并返回单区域安全边界曲线图和顶点。
"""
function get_inertiatodamping_functions(droop_parameters::Real)
    result = mainfun(droop_parameters; verbose=false, show_plot=false)
    return result.plot, result.vertices
end

if (@__MODULE__) == Main
    println("=== Executing single-area mainfun directly ===")
    result = mainfun(33.0; save_vertices=true, save_plot=true)
    println("=== Execution completed successfully ===")
end

