if (@__MODULE__) == Main
    using Pkg
    Pkg.activate(@__DIR__)
    include("src/FrequencyRegions.jl")
    using Plots
    using .FrequencyRegions
    using .FrequencyRegions: DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, OUTPUT_REL_PATH,
        execute_workflow, create_computation_config, default_controller_config,
        vertices_to_matrix, write_vertices_to_file, get_workflow_summary
end

"""
    mainfun(droop::Real=33.0; save_vertices::Bool=false, output_path::String=OUTPUT_REL_PATH) -> ComputationResult

English: Top-level entry point for single-area frequency security region analysis.
Runs the workflow to calculate the frequency security boundary and feasible region vertices.
Chinese: 单区域频率安全区域分析的顶层入口函数。
运行工作流以计算频率安全边界和可行域顶点。

# Arguments (参数)
- `droop`: Governor regulation droop parameter (调速器下垂系数)
- `save_vertices`: Set true to export the vertices to a file (设置为 true 将顶点导出 to 文件)
- `output_path`: Path to save the exported vertices file (导出的顶点文件保存路径)
- `verbose`: Set true to print workflow summary to the console (设置为 true 将打印工作流摘要结果)
- `show_plot`: Set true to display the plot interactively (设置为 true 将在交互环境下显示曲线图)
- `save_plot`: Set true to save the plot to a file (设置为 true 将图表保存为文件)
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
            println("=== [Stage 5/5] Saving visualization plot to $plot_path ===")
        end
        mkpath(dirname(plot_path))
        Plots.savefig(result.plot, plot_path)
        if verbose
            println("Saved single-area plot to: ", plot_path)
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
