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
	config::ComputationConfig,
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

		# Handle infeasible boundary cases
		if isempty(bounds) || size(bounds, 2) < 2
			p = Plots.plot(; framestyle = :box,
				title = "Area $(ar_con.area_id) INFEASIBLE",
				titlelocation = :left,
				titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold),
				xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
				guidefontsize = 9, tickfontsize = 8,
				fontfamily = PLOT_FONT_FAMILY, tickdirection = :out,
				grid = true, gridalpha = 0.12, gridcolor = :grey80,
				left_margin = 15Plots.px, bottom_margin = 12Plots.px,
				top_margin = 5Plots.px, right_margin = 10Plots.px,
				size = (350, 300))
			push!(plots, p)
			continue
		end

		p = Plots.plot(; framestyle = :box,
			title = "Area $(ar_con.area_id) frequency-security region",
			titlefont = Plots.font(9, PLOT_FONT_FAMILY, :bold),
			xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
			guidefontsize = 9, tickfontsize = 8,
			legendfontsize = 8, fontfamily = PLOT_FONT_FAMILY,
			tickdirection = :out,
			grid = true, gridalpha = 0.12, gridcolor = :grey80,
			legend = :topright,
			fg_legend = :transparent,
			bg_legend = :transparent,
			left_margin = 15Plots.px,
			bottom_margin = 12Plots.px,
			top_margin = 5Plots.px,
			right_margin = 10Plots.px,
			size = (350, 300))

		# 1. Local ROCOF limit
		min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
		p = Plots.hline!(p, [min_inertia];
			lw = 1.5, label = "ROCOF limit", color = COLOR_ROCOF_LIMIT, linestyle = :dot)

		# 2. Upper and Lower Bounds (ζ = 1 stability limits)
		max_inertia_vals = bounds[:, 1]
		p = Plots.plot!(p, damp, max_inertia_vals;
			lw = 1.5, label = "Upper bound (ζ = 1)", color = COLOR_UPPER_BOUND)
		p = Plots.plot!(p, damp, bounds[:, 2];
			lw = 1.5, label = "Lower bound (ζ = 1)", color = COLOR_LOWER_BOUND, linestyle = :dash)

		# Index range for damping bounds
		idx_range = findall(d -> config.min_damping <= d <= config.max_damping, damp)

		# 3. Isolated Feasible Region
		if !isempty(r_iso.vertices)
			fit_curve_iso = length(ar_iso.nadir_inertia_limits) == length(damp) ?
				ar_iso.nadir_inertia_limits :
				(r_iso.fitting_parameters[1] .+ r_iso.fitting_parameters[2] .* damp .+
				 r_iso.fitting_parameters[3] .* damp .^ 2)
			fit_curve_iso_plot = [fit_curve_iso[i] <= bounds[i, 1] ? fit_curve_iso[i] : NaN for i in eachindex(damp)]

			if !isempty(idx_range)
				damp_sub = damp[idx_range]
				top_sub = bounds[idx_range, 1]
				bottom_sub_iso = [min(top_sub[i], max(bounds[idx_range[i], 2], min_inertia, fit_curve_iso[idx_range[i]])) for i in eachindex(idx_range)]

				p = Plots.plot!(p, damp_sub, top_sub;
					fillrange = bottom_sub_iso, fillalpha = 0.22, fillcolor = COLOR_FEASIBLE_ISO,
					lw = 0, label = "Feasible (Isolated)")
			end

			# Plot isolated nadir fit curve
			p = Plots.plot!(p, damp, fit_curve_iso_plot;
				lw = 1.5, label = "Isolated Nadir boundary", color = COLOR_FEASIBLE_ISO, linestyle = :dashdot)
		end

		# 4. Interconnected Feasible Region
		if !isempty(r_con.vertices)
			fit_curve_con = length(ar_con.nadir_inertia_limits) == length(damp) ?
				ar_con.nadir_inertia_limits :
				(r_con.fitting_parameters[1] .+ r_con.fitting_parameters[2] .* damp .+
				 r_con.fitting_parameters[3] .* damp .^ 2)
			active_lower_curve = max.(bounds[:, 2], min_inertia, fit_curve_con)
			active_lower_curve_plot = [active_lower_curve[i] <= bounds[i, 1] ? active_lower_curve[i] : NaN for i in eachindex(damp)]

			# Compute active upper curve based on stability and tie-line capacity limit if available
			has_tieline = !isempty(ar_con.tieline_fitting_parameters) || !isempty(ar_con.tieline_inertia_limits)
			
			active_upper_curve = if has_tieline
				tieline_curve = length(ar_con.tieline_inertia_limits) == length(damp) ?
					ar_con.tieline_inertia_limits :
					(ar_con.tieline_fitting_parameters[1] .+ ar_con.tieline_fitting_parameters[2] .* damp .+
					 ar_con.tieline_fitting_parameters[3] .* damp .^ 2)
				[
					(h >= 99.9 || h > bounds[i, 1]) ? bounds[i, 1] : h
					for (i, h) in enumerate(tieline_curve)
				]
			else
				bounds[:, 1]
			end

			if !isempty(idx_range)
				damp_sub = damp[idx_range]
				top_sub = [min(bounds[idx_range[i], 1], active_upper_curve[idx_range[i]]) for i in eachindex(idx_range)]
				bottom_sub_con = [max(bounds[idx_range[i], 2], min_inertia, fit_curve_con[idx_range[i]]) for i in eachindex(idx_range)]
				
				# Prevent negative filling ranges
				for i in eachindex(idx_range)
					if top_sub[i] < bottom_sub_con[i]
						top_sub[i] = bottom_sub_con[i]
					end
				end

				p = Plots.plot!(p, damp_sub, top_sub;
					fillrange = bottom_sub_con, fillalpha = 0.15, fillcolor = COLOR_FEASIBLE_CON,
					lw = 0, label = "Feasible (Interconnected)")
			end

			# Plot the active boundaries as outlines
			p = Plots.plot!(p, damp, active_lower_curve_plot;
				lw = 2.2, label = "Active lower boundary", color = :black, linestyle = :solid)
			
			active_upper_limit_only_plot = [active_upper_curve[i] < bounds[i, 1] ? active_upper_curve[i] : NaN for i in eachindex(damp)]
			p = Plots.plot!(p, damp, active_upper_limit_only_plot;
				lw = 2.2, label = "Active upper boundary", color = :black, linestyle = :dash)

			# Plot separate Nadir and Tieline limit curves if available
			if !isempty(ar_con.nadir_fitting_parameters)
				fit_curve_nadir = length(ar_con.nadir_inertia_limits) == length(damp) ?
					ar_con.nadir_inertia_limits :
					(ar_con.nadir_fitting_parameters[1] .+ ar_con.nadir_fitting_parameters[2] .* damp .+
					 ar_con.nadir_fitting_parameters[3] .* damp .^ 2)
				p = Plots.plot!(p, damp, fit_curve_nadir;
					lw = 1.8, label = "Nadir required inertia", color = :green, linestyle = :dash)
			end
			if !isempty(ar_con.tieline_fitting_parameters)
				# Tie-line transfer can switch sharply from feasible to infeasible;
				# plot the simulated boundary rather than a misleading quadratic fit.
				tieline_curve = length(ar_con.tieline_inertia_limits) == length(damp) ?
					ar_con.tieline_inertia_limits :
					(ar_con.tieline_fitting_parameters[1] .+ ar_con.tieline_fitting_parameters[2] .* damp .+
					 ar_con.tieline_fitting_parameters[3] .* damp .^ 2)
				# H=100 s is the search sentinel for a non-binding tie-line, not a
				# physical boundary. Suppress it so it cannot flatten the Nadir curve.
				tieline_curve = [
					(h >= 99.9 || h > bounds[i, 1] + 1e-6) ? NaN : h
					for (i, h) in enumerate(tieline_curve)
				]
				p = Plots.plot!(p, damp, tieline_curve;
					lw = 1.8, label = "Tie-line capacity upper boundary", color = :red, linestyle = :dot)
			end
		end

		# Damping search limits
		p = Plots.vline!(p, [config.min_damping]; lw = 1.0, label = "Damping limits",
			color = COLOR_DAMPING_BOUNDS, linestyle = :dot)
		p = Plots.vline!(p, [config.max_damping]; lw = 1.0, label = "",
			color = COLOR_DAMPING_BOUNDS, linestyle = :dot)

		push!(plots, p)
	end

	if n_areas == 1
		return plots[1]
	elseif n_areas == 2
		return Plots.plot(plots[1], plots[2]; layout = (1, 2), size = (700, 300))
	else
		return Plots.plot(plots...; layout = (1, n_areas), size = (350 * n_areas, 300))
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
	# Curated desaturated publication palette
	area_colors = [COLOR_UPPER_BOUND, COLOR_ROCOF_LIMIT, COLOR_LOWER_BOUND, COLOR_FIT_CURVE]
	area_alpha = 0.18

	p = Plots.plot(; framestyle = :box,
		xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
		title = "", # No title inside plot
		guidefontsize = 9, tickfontsize = 8,
		legendfontsize = 8, fontfamily = PLOT_FONT_FAMILY,
		tickdirection = :out,
		grid = true, gridalpha = 0.12, gridcolor = :grey80,
		legend = :topright,
		fg_legend = :transparent,
		bg_legend = :transparent,
		left_margin = 15Plots.px,
		bottom_margin = 12Plots.px,
		top_margin = 5Plots.px,
		right_margin = 10Plots.px,
		size = (350, 300))

	for (idx, ar) in enumerate(results)
		verts = ar.result.vertices
		if length(verts) < 3
			continue
		end

		damp_vals = [v[2] for v in verts]
		inert_vals = [v[3] for v in verts]

		color_idx = mod1(idx, length(area_colors))
		p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
			fillalpha = area_alpha, label = "Area $(ar.area_id) (ΔP = $(round(ar.effective_disturbance, digits=2)) p.u.)",
			color = area_colors[color_idx], lw = 1.5, linecolor = area_colors[color_idx])
	end

	p = Plots.vline!(p, [config.min_damping]; lw = 1.0, label = "Damping limits",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)
	p = Plots.vline!(p, [config.max_damping]; lw = 1.0, label = "",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)

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
	config::ComputationConfig,
)
	p_overlay = plot_feasible_region_overlay(results_connected, config)

	if length(results_connected) >= 2
		detail_plots = [plot_multiarea_comparison([results_isolated[i]], [results_connected[i]], system, config) for i in 1:min(length(results_connected), 2)]
		r1, r2 = results_connected[1].result, results_connected[2].result

		p_info = Plots.plot(; framestyle = :box,
			xlims = (0, 1), ylims = (0, 1), showaxis = false,
			ticks = false,
			fontfamily = PLOT_FONT_FAMILY,
			left_margin = 15Plots.px,
			bottom_margin = 12Plots.px,
			top_margin = 5Plots.px,
			right_margin = 10Plots.px)

		info_text =
			"Boundary Fitting Models:\n\n" *
			"Area 1 (Interconnected):\n" *
			"  H = $(round(r1.fitting_parameters[1], digits=2)) + ($(round(r1.fitting_parameters[2], digits=2)))·D + ($(round(r1.fitting_parameters[3], digits=4)))·D²\n\n" *
			"Area 2 (Interconnected):\n" *
			"  H = $(round(r2.fitting_parameters[1], digits=2)) + ($(round(r2.fitting_parameters[2], digits=2)))·D + ($(round(r2.fitting_parameters[3], digits=4)))·D²\n\n" *
			"Feasible Vertices:\n" *
			"  Area 1: $(length(r1.vertices)) points | Area 2: $(length(r2.vertices)) points"

		Plots.annotate!(p_info, 0.05, 0.5, Plots.text(info_text, :left, 8, PLOT_FONT_FAMILY))

		# Add panel labels
		p1 = Plots.plot(detail_plots[1], title = "a", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))
		p2 = Plots.plot(detail_plots[2], title = "b", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))
		p3 = Plots.plot(p_overlay, title = "c", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))
		p4 = Plots.plot(p_info, title = "d", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))

		return Plots.plot(p1, p2, p3, p4; layout = (2, 2), size = (700, 600))
	end

	p_detail = plot_multiarea_comparison(results_isolated, results_connected, system, config)
	p_detail_labeled = Plots.plot(p_detail, title = "a", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))
	p_overlay_labeled = Plots.plot(p_overlay, title = "b", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))

	return Plots.plot(p_detail_labeled, p_overlay_labeled; layout = (1, 2), size = (700, 300))
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
	controller_config::ControllerConfig,
)
	capacities = [0.0, 0.5, 1.0, 4.0]
	colors = [COLOR_ROCOF_LIMIT, COLOR_LOWER_BOUND, COLOR_UPPER_BOUND, COLOR_FIT_CURVE]
	alphas = [0.1, 0.15, 0.2, 0.25]

	p = Plots.plot(; framestyle = :box,
		xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
		title = "", # No title for publication
		guidefontsize = 9, tickfontsize = 8,
		legendfontsize = 8, fontfamily = PLOT_FONT_FAMILY,
		tickdirection = :out,
		grid = true, gridalpha = 0.12, gridcolor = :grey80,
		legend = :topright,
		fg_legend = :transparent,
		bg_legend = :transparent,
		left_margin = 15Plots.px,
		bottom_margin = 12Plots.px,
		top_margin = 5Plots.px,
		right_margin = 10Plots.px,
		size = (350, 300))

	area = first([a for a in system.areas if a.id == area_id])

	for (idx, C12) in enumerate(capacities)
		modified_tie_lines = [TieLine(tl.from_area, tl.to_area, tl.synchronizing_coeff, C12) for tl in system.tie_lines]
		modified_sys = MultiAreaSystem(system.areas, modified_tie_lines)

		ar_result = execute_dynamic_area_workflow(area, modified_sys, config, controller_config)
		verts = ar_result.result.vertices

		if length(verts) < 3
			continue
		end

		damp_vals = [v[2] for v in verts]
		inert_vals = [v[3] for v in verts]

		label = C12 == 0.0 ? "Isolated (C12 = 0)" : "Capacity C12 = $C12"
		p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
			fillalpha = alphas[idx], label = label,
			color = colors[idx], lw = 1.5, linecolor = colors[idx])
	end

	min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
	p = Plots.hline!(p, [min_inertia];
		lw = 1.5, label = "ROCOF limit", color = COLOR_ROCOF_LIMIT, linestyle = :dot)

	p = Plots.vline!(p, [config.min_damping]; lw = 1.0, label = "Damping limits",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)
	p = Plots.vline!(p, [config.max_damping]; lw = 1.0, label = "",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)

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
	controller_config::ControllerConfig,
)
	stiffnesses = [0.2, 1.0, 4.0, 10.0]
	colors = [COLOR_ROCOF_LIMIT, COLOR_LOWER_BOUND, COLOR_UPPER_BOUND, COLOR_FIT_CURVE]
	alphas = [0.1, 0.15, 0.2, 0.25]

	p = Plots.plot(; framestyle = :box,
		xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
		title = "", # No title for publication
		guidefontsize = 9, tickfontsize = 8,
		legendfontsize = 8, fontfamily = PLOT_FONT_FAMILY,
		tickdirection = :out,
		grid = true, gridalpha = 0.12, gridcolor = :grey80,
		legend = :topright,
		fg_legend = :transparent,
		bg_legend = :transparent,
		left_margin = 15Plots.px,
		bottom_margin = 12Plots.px,
		top_margin = 5Plots.px,
		right_margin = 10Plots.px,
		size = (350, 300))

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
			color = colors[idx], lw = 1.5, linecolor = colors[idx])
	end

	min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)
	p = Plots.hline!(p, [min_inertia];
		lw = 1.5, label = "ROCOF limit", color = COLOR_ROCOF_LIMIT, linestyle = :dot)

	p = Plots.vline!(p, [config.min_damping]; lw = 1.0, label = "Damping limits",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)
	p = Plots.vline!(p, [config.max_damping]; lw = 1.0, label = "",
		color = COLOR_DAMPING_BOUNDS, linestyle = :dot)

	return p
end



"""
	plot_multiarea_mutual_support_trajectories(system::MultiAreaSystem, config::ComputationConfig) -> Any

English: Simulates and plots the time-domain frequency response and tie-line power flow under a contingency in Area 1.
Compares isolated state (C12 = 0) vs interconnected state (C12 > 0) to demonstrate the physical mechanism.
Chinese: 模拟并绘制区域 1 发生扰动时系统频率和联络线交换功率的时域响应曲线，对比孤立与互联状态，阐述物理机理。
"""
function plot_multiarea_mutual_support_trajectories(system::MultiAreaSystem, config::ComputationConfig)
	a1 = system.areas[1]
	a2 = system.areas[2]
	tl = system.tie_lines[1]

	# Simulation parameters
	# Let's fix a damping point: D1 = D2 = 4.0 p.u. (in search range)
	D_val = 4.0

	# 1. Simulate Case 1: Isolated (C12 = 0.0)
	t_iso, df1_iso, df2_iso, P_iso = simulate_multiarea_frequency_history(
		a1.initial_inertia, D_val, a1.droop, a1.time_constant, a1.factorial_coefficient, a1.power_deviation,
		a2.initial_inertia, D_val, a2.droop, a2.time_constant, a2.factorial_coefficient, 0.0,
		tl.synchronizing_coeff, 0.0;
		t_max=15.0
	)

	# 2. Simulate Case 2: Interconnected (C12 = nominal capacity)
	t_con, df1_con, df2_con, P_con = simulate_multiarea_frequency_history(
		a1.initial_inertia, D_val, a1.droop, a1.time_constant, a1.factorial_coefficient, a1.power_deviation,
		a2.initial_inertia, D_val, a2.droop, a2.time_constant, a2.factorial_coefficient, 0.0,
		tl.synchronizing_coeff, tl.capacity;
		t_max=15.0
	)

	# Convert frequency deviation from p.u. to Hz and get actual frequency (f = 50 + 50 * df)
	f1_iso = 50.0 .+ 50.0 .* df1_iso
	f2_iso = 50.0 .+ 50.0 .* df2_iso
	f1_con = 50.0 .+ 50.0 .* df1_con
	f2_con = 50.0 .+ 50.0 .* df2_con

	# Plot panel a: Frequency curves
	p_freq = Plots.plot(;
		framestyle = :box,
		fontfamily = PLOT_FONT_FAMILY,
		tickdirection = :out,
		grid = true, gridalpha = 0.12, gridcolor = :grey80,
		xlabel = "Time, t (s)", ylabel = "Frequency, f (Hz)",
		title = "",
		guidefontsize = 9, tickfontsize = 8,
		legendfontsize = 8,
		fg_legend = :transparent,
		bg_legend = :transparent,
		left_margin = 15Plots.px,
		bottom_margin = 12Plots.px,
		top_margin = 5Plots.px,
		right_margin = 10Plots.px,
		size = (350, 300),
	)

	Plots.hline!(p_freq, [50.0 - a1.nadir_threshold]; lw = 1.2, color = COLOR_ROCOF_LIMIT, linestyle = :dash, label = "Nadir Limit")
	Plots.plot!(p_freq, t_iso, f1_iso; lw = 1.5, color = COLOR_VERIFY_C, label = "Area 1 (Isolated)")
	Plots.plot!(p_freq, t_con, f1_con; lw = 1.5, color = COLOR_UPPER_BOUND, label = "Area 1 (Interconnected)")
	Plots.plot!(p_freq, t_con, f2_con; lw = 1.5, color = COLOR_LOWER_BOUND, linestyle = :dash, label = "Area 2 (Interconnected)")

	# Plot panel b: Tie-line Power
	p_tie = Plots.plot(;
		framestyle = :box,
		fontfamily = PLOT_FONT_FAMILY,
		tickdirection = :out,
		grid = true, gridalpha = 0.12, gridcolor = :grey80,
		xlabel = "Time, t (s)", ylabel = "Tie-line Power, P_tie (p.u.)",
		title = "",
		guidefontsize = 9, tickfontsize = 8,
		legendfontsize = 8,
		fg_legend = :transparent,
		bg_legend = :transparent,
		left_margin = 15Plots.px,
		bottom_margin = 12Plots.px,
		top_margin = 5Plots.px,
		right_margin = 10Plots.px,
		size = (350, 300),
	)

	Plots.plot!(p_tie, t_con, P_con; lw = 1.5, color = COLOR_FIT_CURVE, label = "P_tie (Interconnected)")
	Plots.hline!(p_tie, [tl.capacity]; lw = 1.2, color = COLOR_ROCOF_LIMIT, linestyle = :dash, label = "C12 Limit")

	p_freq_labeled = Plots.plot(p_freq, title = "a", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))
	p_tie_labeled = Plots.plot(p_tie, title = "b", titlelocation = :left, titlefont = Plots.font(10, PLOT_FONT_FAMILY, :bold))

	combined_plot = Plots.plot(p_freq_labeled, p_tie_labeled;
		layout = (1, 2),
		size = (700, 300),
	)

	return combined_plot
end

