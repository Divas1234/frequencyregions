"""
    multi_area/visualization.jl

English: Visualization utilities for multi-area frequency security region analysis.
Generates side-by-side comparison plots, overlays, and parameter impact curves.
Chinese: 多区域频率安全区域分析的可视化工具。
生成并排对比图、重叠图以及参数影响特性曲线。
"""

"""
    plot_multiarea_comparison(results_isolated::Vector{AreaResult}, results_connected::Vector{AreaResult},
                              system::MultiAreaSystem, config::ComputationConfig) -> Any

English: Creates a multi-panel figure comparing the H-D feasible regions of all areas under
isolated vs interconnected (tie-line sharing) states, showing the exact expansion.
Chinese: 创建一个多子图对比分析图，展示各控制区域在孤立与互联（联络线支援共享）状态下的 H-D 可行域范围，说明其安全区域拓宽效果。

# Arguments (参数)
- `results_isolated`: Simulation results in isolated state (孤立状态计算结果)
- `results_connected`: Simulation results in interconnected state (互联状态计算结果)
- `system`: Multi-area system structure (多区域电网拓扑结构)
- `config`: Computation configuration (计算设置)
"""
function plot_multiarea_comparison(
    results_isolated::Vector{AreaResult},
    results_connected::Vector{AreaResult},
    system::MultiAreaSystem,
    config::ComputationConfig
)
    n_areas = length(results_connected)
    plots = []

    for idx in 1:n_areas
        ar_iso = results_isolated[idx]
        ar_con = results_connected[idx]
        area = first([a for a in system.areas if a.id == ar_con.area_id])

        r_iso = ar_iso.result
        r_con = ar_con.result
        damp = collect(config.damping_range)
        bounds = collect(r_con.inertia_bounds)

        # Handle infeasible boundary cases (若无可行边界限制，绘制空警示子图)
        if isempty(bounds) || size(bounds, 2) < 2
            p = Plots.plot(; framestyle = :box,
                           title = "Area $(ar_con.area_id) (Contingency = $(area.power_deviation) p.u., INFEASIBLE)",
                           xlabel = "Damping D / p.u.", ylabel = "Inertia H / s",
                           titlefontsize = 10, guidefontsize = 10, tickfontsize = 9,
                           fontfamily = "Computer Modern", grid = true, gridalpha = 0.2, gridstyle = :dash)
            push!(plots, p)
            continue
        end

        p = Plots.plot(; framestyle = :box,
                       title = "Area $(ar_con.area_id) (Contingency = $(area.power_deviation) p.u.)",
                       xlabel = "Damping D / p.u.", ylabel = "Inertia H / s",
                       titlefontsize = 10, guidefontsize = 10, tickfontsize = 9,
                       legendfontsize = 8, fontfamily = "Computer Modern",
                       grid = true, gridalpha = 0.2, gridstyle = :dash,
                       legend = :topright)

        # 1. Local ROCOF limit (independent of tie-line since tieline power P_tie=0 at t=0+)
        # 本地 ROCOF 变化率限制（故障瞬时联络线交换有功为0，ROCOF只与本地惯性负荷有功额定偏差相关）
        min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
        p = Plots.hline!(p, [min_inertia];
            lw = 1.8, label = "ROCOF limit", color = :darkred, linestyle = :dash, alpha = 0.8)

        # 2. Upper and Lower Bounds (ζ = 1 stability limits / 阻尼比限制稳定上下边界)
        max_inertia_vals = bounds[:, 1]
        p = Plots.plot!(p, damp, max_inertia_vals;
            lw = 2.0, label = "Upper bound (ζ = 1)", color = :blue, alpha = 0.8)
        p = Plots.plot!(p, damp, bounds[:, 2];
            lw = 2.0, label = "Lower bound (ζ = 1)", color = :forestgreen, linestyle = :dash, alpha = 0.8)

        # Index range for damping bounds
        idx_range = findall(d -> config.min_damping <= d <= config.max_damping, damp)

        # 3. Isolated Feasible Region (C12 = 0 / 孤立运行可行域)
        if !isempty(r_iso.vertices)
            fit_curve_iso = r_iso.fitting_parameters[1] .+ r_iso.fitting_parameters[2] .* damp .+
                            r_iso.fitting_parameters[3] .* damp .^ 2

            if !isempty(idx_range)
                damp_sub = damp[idx_range]
                top_sub = bounds[idx_range, 1]
                bottom_sub_iso = [min(top_sub[i], max(bounds[idx_range[i], 2], min_inertia, fit_curve_iso[idx_range[i]])) for i in eachindex(idx_range)]

                p = Plots.plot!(p, damp_sub, top_sub;
                    fillrange = bottom_sub_iso, fillalpha = 0.22, fillcolor = :darkorange,
                    lw = 0, label = "Feasible Region (Isolated)")
            end

            # Plot isolated nadir fit curve (绘制孤立状态下的 Nadir 二次拟合边界曲线)
            p = Plots.plot!(p, damp, fit_curve_iso;
                lw = 1.5, label = "Isolated Nadir Fit", color = :darkorange, linestyle = :dot)
        end

        # 4. Interconnected Feasible Region (with tie-line power sharing / 互联模式可行域)
        if !isempty(r_con.vertices)
            fit_curve_con = r_con.fitting_parameters[1] .+ r_con.fitting_parameters[2] .* damp .+
                            r_con.fitting_parameters[3] .* damp .^ 2

            if !isempty(idx_range)
                damp_sub = damp[idx_range]
                top_sub = bounds[idx_range, 1]
                bottom_sub_con = [min(top_sub[i], max(bounds[idx_range[i], 2], min_inertia, fit_curve_con[idx_range[i]])) for i in eachindex(idx_range)]

                p = Plots.plot!(p, damp_sub, top_sub;
                    fillrange = bottom_sub_con, fillalpha = 0.15, fillcolor = :royalblue,
                    lw = 0, label = "Feasible Region (Interconnected)")
            end

            # Plot interconnected nadir fit curve (绘制互联状态下的 Nadir 二次拟合边界曲线)
            p = Plots.plot!(p, damp, fit_curve_con;
                lw = 2.0, label = "Interconnected Nadir Fit", color = :royalblue, linestyle = :dashdot)
        end

        # Damping search limits (阻尼搜索上下限指示虚线)
        p = Plots.vline!(p, [config.min_damping]; lw = 1.2, label = "Damping bounds",
                         color = :gray, linestyle = :dot, alpha = 0.8)
        p = Plots.vline!(p, [config.max_damping]; lw = 1.2, label = "",
                         color = :gray, linestyle = :dot, alpha = 0.8)

        push!(plots, p)
    end

    if n_areas == 1
        return plots[1]
    elseif n_areas == 2
        return Plots.plot(plots[1], plots[2]; layout = (1, 2), size = (1200, 480),
                          plot_title = "Multi-Area Feasible Regions Comparison (Isolated vs Interconnected)",
                          titlefont = (11, "Computer Modern"))
    else
        return Plots.plot(plots...; layout = (1, n_areas), size = (400 * n_areas, 480),
                          plot_title = "Multi-Area Feasible Regions Comparison (Isolated vs Interconnected)",
                          titlefont = (11, "Computer Modern"))
    end
end


"""
    plot_feasible_region_overlay(results::Vector{AreaResult}, config::ComputationConfig) -> Any

English: Overlays the feasible region polygons of all areas on a single plot for
direct comparison. Polygon boundaries show the intersection of all constraints.
Chinese: 将所有控制区域的可行域多边形重叠绘制在同一张图表上进行直观比较。多边形边界为各项安全约束的交集。

# Returns (返回)
- Plots.jl plot object (Plots 绘图对象)
"""
function plot_feasible_region_overlay(results::Vector{AreaResult}, config::ComputationConfig)
    area_colors = [:royalblue, :crimson, :forestgreen, :darkorchid]
    area_alpha = 0.18

    p = Plots.plot(; framestyle = :box,
                   xlabel = "Damping D / p.u.", ylabel = "Inertia H / s",
                   title = "Multi-Area Feasible Region Comparison (Overlay)",
                   titlefontsize = 11, guidefontsize = 10, tickfontsize = 9,
                   legendfontsize = 9, fontfamily = "Computer Modern",
                   grid = true, gridalpha = 0.2, gridstyle = :dash,
                   legend = :topright, size = (700, 480))

    for (idx, ar) in enumerate(results)
        verts = ar.result.vertices
        if length(verts) < 3
            continue
        end

        damp_vals = [v[2] for v in verts]
        inert_vals = [v[3] for v in verts]

        # Draw filled polygons representing the dynamic security boundaries
        # 绘制填充的多边形，代表各区的安全可行区域
        p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
            fillalpha = area_alpha, label = "Area $(ar.area_id) (ΔP = $(round(ar.effective_disturbance, digits=2)) p.u.)",
            color = area_colors[idx], lw = 2.0, linecolor = area_colors[idx])
    end

    p = Plots.vline!(p, [config.min_damping]; lw = 1.2, label = "D damping bounds",
                     color = :gray, linestyle = :dot)
    p = Plots.vline!(p, [config.max_damping]; lw = 1.2, label = "",
                     color = :gray, linestyle = :dot)

    return p
end


"""
    plot_combined_summary(results_isolated::Vector{AreaResult}, results_connected::Vector{AreaResult},
                          system::MultiAreaSystem, config::ComputationConfig) -> Any

English: Creates a comprehensive 2x2 summary figure:
1. Top-left:  Area 1 isolated vs connected comparison
2. Top-right: Area 2 isolated vs connected comparison
3. Bottom-left:  Overlay of connected feasible polygons
4. Bottom-right: Parameter comparison table (text annotation)
Chinese: 创建一个综合的 2x2 汇总分析图：
1. 左上： 区域 1 孤立与互联安全区域对比
2. 右上： 区域 2 孤立与互联安全区域对比
3. 左下： 互联状态下两个区域的可行多边形重叠图
4. 右下： 拟合参数数学公式汇总表格说明

# Returns (返回)
- Plots.jl plot object (Plots 绘图对象)
"""
function plot_combined_summary(
    results_isolated::Vector{AreaResult},
    results_connected::Vector{AreaResult},
    system::MultiAreaSystem,
    config::ComputationConfig
)
    p_overlay = plot_feasible_region_overlay(results_connected, config)

    if length(results_connected) >= 2
        detail_plots = [plot_multiarea_comparison([results_isolated[i]], [results_connected[i]], system, config) for i in 1:min(length(results_connected), 2)]
        r1, r2 = results_connected[1].result, results_connected[2].result
        info_text = "Area 1: H = $(round(r1.fitting_parameters[1], digits=2)) + $(round(r1.fitting_parameters[2], digits=2))·D + $(round(r1.fitting_parameters[3], digits=2))·D²\n\nArea 2: H = $(round(r2.fitting_parameters[1], digits=2)) + $(round(r2.fitting_parameters[2], digits=2))·D + $(round(r2.fitting_parameters[3], digits=2))·D²\n\nVertices: A1=$(length(r1.vertices)), A2=$(length(r2.vertices))"

        p_info = Plots.plot(; framestyle = :box, title = "Parameter Summary",
                            xlims = (0, 1), ylims = (0, 1), showaxis = false,
                            ticks = false)
        Plots.annotate!(p_info, 0.5, 0.5, Plots.text(info_text, :black, 10))

        return Plots.plot(detail_plots[1], detail_plots[2], p_overlay, p_info;
            layout = (2, 2), size = (1400, 1000))
    end

    p_detail = plot_multiarea_comparison(results_isolated, results_connected, system, config)
    return Plots.plot(p_detail, p_overlay; layout = (1, 2), size = (1400, 550))
end

"""
    plot_sharing_capacity_impact(area_id::Int, system::MultiAreaSystem,
                                 config::ComputationConfig, controller_config::ControllerConfig) -> Any

English: Plots the impact of tie-line transmission capacity limit (C12) on the security region of the specified area.
Runs the dynamic simulation for different capacities (e.g., 0.0, 0.5, 1.0, 4.0) and overlays the resulting polygons.
Chinese: 绘制联络线传输容量极限 (C12) 对指定区域频率安全区域范围的影响。
针对不同的通道极限（如 0.0, 0.5, 1.0, 4.0 p.u.）运行动态仿真并重叠对比可行多边形。
"""
function plot_sharing_capacity_impact(
    area_id::Int,
    system::MultiAreaSystem,
    config::ComputationConfig,
    controller_config::ControllerConfig
)
    # Define capacities to evaluate (定义需要评估的联络线容量梯度)
    capacities = [0.0, 0.5, 1.0, 4.0]
    colors = [:darkorange, :limegreen, :royalblue, :purple]
    alphas = [0.1, 0.15, 0.2, 0.25]

    p = Plots.plot(; framestyle = :box,
                   xlabel = "Damping D / p.u.", ylabel = "Inertia H / s",
                   title = "Impact of Tie-line Capacity on Area $area_id Security Region",
                   titlefontsize = 11, guidefontsize = 10, tickfontsize = 9,
                   legendfontsize = 9, fontfamily = "Computer Modern",
                   grid = true, gridalpha = 0.2, gridstyle = :dash,
                   legend = :topright, size = (750, 500))

    # Retrieve local area parameters (提取本地控制区域固有参数)
    area = first([a for a in system.areas if a.id == area_id])

    for (idx, C12) in enumerate(capacities)
        # Create a modified system with the specific tie-line capacity (修改系统参数中的联络线容量)
        modified_tie_lines = [TieLine(tl.from_area, tl.to_area, tl.synchronizing_coeff, C12) for tl in system.tie_lines]
        modified_sys = MultiAreaSystem(system.areas, modified_tie_lines)

        # Run dynamic simulation workflow for this modified system
        # 运行修改后系统的动态支援工作流
        ar_result = execute_dynamic_area_workflow(area, modified_sys, config, controller_config)
        verts = ar_result.result.vertices

        if length(verts) < 3
            # Infeasible or not enough vertices (如果不可行，则跳过)
            continue
        end

        damp_vals = [v[2] for v in verts]
        inert_vals = [v[3] for v in verts]

        label = C12 == 0.0 ? "Isolated (C12 = 0)" : "Capacity C12 = $C12"
        p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
            fillalpha = alphas[idx], label = label,
            color = colors[idx], lw = 2.0, linecolor = colors[idx])
    end

    # Plot local ROCOF limit (which is capacity independent)
    # 绘制本地 ROCOF 极限水平切线
    min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
    p = Plots.hline!(p, [min_inertia];
        lw = 1.5, label = "ROCOF limit", color = :darkred, linestyle = :dash, alpha = 0.8)

    p = Plots.vline!(p, [config.min_damping]; lw = 1.2, label = "D damping bounds",
                     color = :gray, linestyle = :dot)
    p = Plots.vline!(p, [config.max_damping]; lw = 1.2, label = "",
                     color = :gray, linestyle = :dot)

    return p
end

"""
    plot_sharing_stiffness_impact(area_id::Int, system::MultiAreaSystem,
                                  config::ComputationConfig, controller_config::ControllerConfig) -> Any

English: Plots the impact of tie-line synchronizing coefficient (stiffness T12) on the security region of the specified area.
Runs the dynamic simulation for different stiffnesses (e.g., 0.2, 1.0, 4.0, 10.0) with nominal capacity.
Chinese: 绘制联络线同步功率系数（即电网耦合刚度 T12）对指定区域频率安全区域范围的影响。
针对不同的刚度系数（如 0.2, 1.0, 4.0, 10.0 p.u.）进行仿真计算并显示对比。
"""
function plot_sharing_stiffness_impact(
    area_id::Int,
    system::MultiAreaSystem,
    config::ComputationConfig,
    controller_config::ControllerConfig
)
    stiffnesses = [0.2, 1.0, 4.0, 10.0]
    colors = [:crimson, :forestgreen, :royalblue, :darkorchid]
    alphas = [0.1, 0.15, 0.2, 0.25]

    p = Plots.plot(; framestyle = :box,
                   xlabel = "Damping D / p.u.", ylabel = "Inertia H / s",
                   title = "Impact of Tie-line Stiffness T12 on Area $area_id Security Region",
                   titlefontsize = 11, guidefontsize = 10, tickfontsize = 9,
                   legendfontsize = 9, fontfamily = "Computer Modern",
                   grid = true, gridalpha = 0.2, gridstyle = :dash,
                   legend = :topright, size = (750, 500))

    area = first([a for a in system.areas if a.id == area_id])

    for (idx, T12) in enumerate(stiffnesses)
        modified_tie_lines = [TieLine(tl.from_area, tl.to_area, T12, tl.capacity) for tl in system.tie_lines]
        modified_sys = MultiAreaSystem(system.areas, modified_tie_lines)

        ar_result = execute_dynamic_area_workflow(area, modified_sys, config, controller_config)
        verts = ar_result.result.vertices

        if length(verts) < 3
            continue
        end

        damp_vals = [v[2] for v in verts]
        inert_vals = [v[3] for v in verts]

        p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
            fillalpha = alphas[idx], label = "Stiffness T12 = $T12",
            color = colors[idx], lw = 2.0, linecolor = colors[idx])
    end

    min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
    p = Plots.hline!(p, [min_inertia];
        lw = 1.5, label = "ROCOF limit", color = :darkred, linestyle = :dash, alpha = 0.8)

    p = Plots.vline!(p, [config.min_damping]; lw = 1.2, label = "D damping bounds",
                     color = :gray, linestyle = :dot)
    p = Plots.vline!(p, [config.max_damping]; lw = 1.2, label = "",
                     color = :gray, linestyle = :dot)

    return p
end
