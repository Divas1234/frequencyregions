"""
	visualization_multi_area.jl

Extended visualization tools for multi-area frequency security regions.
Provides comparison plots between single-area and multi-area constraints.
"""

using Plots
using QHull

"""
	plot_multi_area_comparison(single_area_result::ComputationResult, multi_area_result::ComputationResult)

Generates a comparison plot showing how multi-area constraints affect the feasible region.
"""
function plot_multi_area_comparison(single_area_result::ComputationResult, multi_area_result::ComputationResult)
	# IEEE academic style setup
	# Avoid forcing a font that may not exist on all systems (prevents GR font warnings)
	p = plot(;
		title = "Inertia-Damping Security Region: Single vs Multi-Area",
		xlabel = "Total System Damping (p.u.)",
		ylabel = "Total System Inertia (p.u.)",
		legend = :topright,
		grid = true,
		gridalpha = 0.2,
		framestyle = :box,
		size = (800, 600),
	)

	# Extract data
	damping_vals = collect(DAMPING_RANGE) # Using global constant

	# 1. Plot Single Area Feasible Region (as a baseline)
	# We use a light color for the single area region
	plot!(p, damping_vals, single_area_result.inertia_bounds[:, 1];
		fillrange = single_area_result.inertia_bounds[:, 2],
		fillalpha = 0.15, fillcolor = :blue, linealpha = 0.3,
		label = "Single Area (Aggregated) Region",)

	# 2. Plot Multi-Area Feasible Region
	# We use a darker color for the multi-area region
	# Note: multi_area_result should have the local RoCoF constraints already applied to result.vertices
	# But for the plot, we'll draw the boundaries.

	# The nadir bound (same as single area if aggregated)
	# The RoCoF, Tie-line, and Diff-mode bounds are now integrated into the lower bound

	plot!(p, damping_vals, multi_area_result.inertia_bounds[:, 1];
		lc = :blue, lw = 2, label = "Upper Bound (Aggregated)",)

	# Find the "bite" point where multi-area constraints become more restrictive than nadir
	plot!(p, damping_vals, multi_area_result.inertia_bounds[:, 2];
		lc = :red, lw = 2, label = "Multi-Area Lower Bound (Integrated)",)

	# Highlight the feasible region
	# ...

	return p
end

"""
	plot_multi_area_regions(results_by_area::Dict{String, ComputationResult})

Generates a plot showing feasible regions for each disturbance area (separate multi-area runs).
"""
function plot_multi_area_regions(results_by_area::Dict{String, ComputationResult})
	# IEEE academic style setup
	p = plot(;
		title = "Multi-Area Security Regions by Disturbance Area",
		xlabel = "Total System Damping (p.u.)",
		ylabel = "Total System Inertia (p.u.)",
		legend = :topright,
		grid = true,
		gridalpha = 0.2,
		framestyle = :box,
		size = (900, 650),
	)

	damping_vals = collect(DAMPING_RANGE)

	# Plot each area region (upper vs lower bounds)
	for (area_name, result) in sort(collect(results_by_area); by = x -> x[1])
		plot!(p, damping_vals, result.inertia_bounds[:, 1];
			fillrange = result.inertia_bounds[:, 2],
			fillalpha = 0.12,
			linealpha = 0.6,
			label = "$(area_name) Region",
		)
		plot!(p, damping_vals, result.inertia_bounds[:, 2];
			lw = 2, label = "$(area_name) Lower Bound",
		)
	end

	return p
end

"""
	plot_multi_area_ieee_regions(multi_config::MultiAreaConfig,
								comp_cfg::ComputationConfig,
								controller_cfg::ControllerConfig)

Generates a plot showing feasible regions for each disturbance area using an
IEEE-style intersection of constraints (similar to single-area plots).
"""
function plot_multi_area_ieee_regions(
		multi_config::MultiAreaConfig,
		comp_cfg::ComputationConfig,
		controller_cfg::ControllerConfig,
)
	# Base plot style
	p = plot(;
		title = "Multi-Area Security Regions (IEEE-style)",
		xlabel = "Damping (p.u.)",
		ylabel = "Inertia (p.u.)",
		legend = :topright,
		grid = true,
		gridalpha = 0.15,
		gridstyle = :dash,
		framestyle = :box,
		size = (900, 650),
	)

	# Softer, paper-friendly palette for overlapping regions
	colors = palette(:Set2)
	damping_vals = collect(comp_cfg.damping_range)

	for (idx, area) in enumerate(multi_config.areas)
		area_config = MultiAreaConfig(
			multi_config.areas,
			multi_config.tie_line_limits,
			area.name,
			multi_config.default_tieline_stiffness,
		)

		# --- Compute result using the standard workflow (ensures consistency) ---
		result = execute_multi_area_workflow(area_config, comp_cfg, controller_cfg)

		# Aggregate system parameters for reference curves
		base_system = create_system_parameters(comp_cfg.flag_converter)
		coi_system = aggregate_to_system_parameters(area_config, base_system)
		_, coi_max_h = estimate_inertia_limits(
			coi_system.rocof_threshold,
			coi_system.power_deviation,
			comp_cfg.damping_range,
			coi_system.factorial_coefficient,
			coi_system.time_constant,
			coi_system.droop,
		)

		fit_coeffs = result.fitting_parameters
		fit_curve = @. fit_coeffs[1] + fit_coeffs[2] * damping_vals + fit_coeffs[3] * damping_vals^2

		max_rocof = vec(coi_max_h)
		upper_bound = result.inertia_bounds[:, 1]
		lower_bound = result.inertia_bounds[:, 2]

		# Use the computed lower bound and the most restrictive multi-area minimum;
		# keep the fitted curve for visual reference (not as a hard constraint).
		h_low = lower_bound
		h_up = upper_bound

		# Use vertices from the workflow result to draw the feasible region
		points = result.vertices
		if length(points) < 3
			@warn "Not enough vertices to plot region for disturbance in $(area.name)."
			continue
		end

		poly_x = [pnt[2] for pnt in points]
		poly_y = [pnt[3] for pnt in points]

		try
			hull = chull(hcat(poly_x, poly_y))
			plot!(p, poly_x[hull.vertices], poly_y[hull.vertices];
				seriestype = :shape,
				fillalpha = 0.28,
				fillcolor = colors[mod1(idx, length(colors))],
				linecolor = colors[mod1(idx, length(colors))],
				linewidth = 1.2,
				label = "$(area.name) Region",
			)
		catch
			plot!(p, poly_x, poly_y;
				seriestype = :shape,
				fillalpha = 0.28,
				fillcolor = colors[mod1(idx, length(colors))],
				linecolor = colors[mod1(idx, length(colors))],
				linewidth = 1.2,
				label = "$(area.name) Region",
			)
		end

		# Add constraint lines for reference (lightweight and consistent)
		plot!(p, damping_vals, upper_bound;
			color = colors[mod1(idx, length(colors))],
			lw = 1.2, linestyle = :solid, label = "",)
		plot!(p, damping_vals, lower_bound;
			color = colors[mod1(idx, length(colors))],
			lw = 1.0, linestyle = :dash, label = "",)
		plot!(p, damping_vals, fit_curve;
			color = colors[mod1(idx, length(colors))],
			lw = 1.0, linestyle = :dot, label = "",)
		hline!(p, [minimum(lower_bound)];
			color = colors[mod1(idx, length(colors))],
			lw = 1.0, linestyle = :dashdot, label = "",)
	end

	return p
end

"""
	create_multi_area_report(result::ComputationResult, multi_config::MultiAreaConfig)

Generates a formatted report for the multi-area analysis.
"""
function create_multi_area_report(result::ComputationResult, multi_config::MultiAreaConfig)
	println("-"^50)
	println("MULTI-AREA FREQUENCY SECURITY REPORT")
	println("-"^50)
	println("Disturbance Area: $(multi_config.disturbance_area_name)")
	println("Number of Areas:  $(length(multi_config.areas))")

	total_h = sum(a.inertia for a in multi_config.areas)
	total_d = sum(a.damping for a in multi_config.areas)
	disturbed_area = first(filter(a -> a.name == multi_config.disturbance_area_name, multi_config.areas))
	disturbed_h = disturbed_area.inertia

	println("Initial Total Inertia: $total_h p.u.")
	println("Initial Total Damping: $total_d p.u.")
	println("Disturbed Area Inertia Ratio: $(round(disturbed_h/total_h * 100, digits=1))%")

	# Tie-line and Differential Info
	p_tie_limit = Inf
	for ((a1, a2), limit) in multi_config.tie_line_limits
		if a1 == disturbed_area.name || a2 == disturbed_area.name
			p_tie_limit = min(p_tie_limit, limit)
		end
	end
	println("Tie-line Power Limit:  $(isinf(p_tie_limit) ? "None" : p_tie_limit) MW/pu")
	println("Tieline Stiffness (T): $(disturbed_area.tieline_stiffness) p.u.")

	println("\nFEASIBLE REGION SUMMARY:")
	println("Vertices found: $(length(result.vertices))")
	if !isempty(result.vertices)
		min_h_found = minimum(v[3] for v in result.vertices)
		println("Minimum Required Total Inertia: $(round(min_h_found, digits=2)) p.u.")

		if total_h < min_h_found
			println("WARNING: Current total inertia is BELOW minimum requirement!")
		else
			println("STATUS: Total inertia is within safe bounds.")
		end
	end
	println("-"^50)
end
