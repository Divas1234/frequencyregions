using Plots
using QHull
include("inertia_damping_fitting.jl")

"""
	data_visualization(damping, inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids; min_inertia=0.0, max_inertia=1.0)

Visualizes the relationship between damping, inertia, and nadir distribution.

# Arguments

  - `damping`: A vector of damping values (p.u.).
  - `inertia_updown_bindings`: A matrix where each row represents a damping value, and the two columns represent the upper and lower inertia bounds (p.u.).
  - `extreme_inertia`: A vector of extreme inertia values (p.u.) corresponding to each damping value.
  - `nadir_vector`: A matrix representing the nadir distribution.
  - `inertia_vector`: A matrix representing the inertia distribution.
  - `selected_ids`: (Not used in the current implementation, but kept for potential future use).
  - `min_inertia`: The minimum inertia value (default: 0.0).
  - `max_inertia`: The maximum inertia value (default: 1.0).

# Returns

  - A Plots.Plot object containing the visualizations.
"""
function data_visualization(
		damping,
		inertia_updown_bindings,
		extreme_inertia,
		nadir_vector,
		inertia_vector,
		selected_ids,
		max_inertia,
		min_inertia = 0.0,
)

	# --- Plot 1: Extreme Inertia ---
	sp1 = plot(
		damping,
		extreme_inertia;
		lw = 3,
		framestyle = :box,
		ylims = (0, maximum(extreme_inertia)),
		xlabel = "damping / p.u.",
		ylabel = "max inertia / p.u.",
		title = "Extreme Inertia",
		label = "Extreme Inertia",
		legend = :topleft,
		grid = true,
	)
	plot!(
		sp1,
		damping,
		extreme_inertia;
		fillrange = inertia_updown_bindings[:, 1],
		fillalpha = 0.3,
		label = "Inertia Range",
		color = :skyblue,
	)

	# --- Plot 2: Nadir Distribution ---
	sp2 = heatmap(
		nadir_vector;
		framestyle = :box,
		xlabel = "Damping",
		ylabel = "nadir distribution",
		title = "Nadir Distribution",
		grid = false,
		colorbar_title = "Value",
	)

	# --- Plot 3: Inertia Distribution ---
	sp3 = heatmap(
		inertia_vector;
		framestyle = :box,
		xlabel = "Damping",
		ylabel = "inertia distribution",
		title = "Inertia Distribution",
		grid = false,
		colorbar_title = "Value",
	)

	# --- Fitting and Interaction Point Calculation ---
	fittingparameters = calculate_fittingparameters(extreme_inertia, damping)

	fillarea = zeros(length(damping))
	for i in eachindex(damping)
		fitted_value = fittingparameters[1] +
					   fittingparameters[2] * damping[i] +
					   fittingparameters[3] * damping[i]^2
		fillarea[i] = max(fitted_value, min_inertia)
	end

	fitted_curve = fittingparameters[1] .+ fittingparameters[2] .* damping .+
				   fittingparameters[3] .* damping .^ 2
	seq = fitted_curve .- max_inertia

	interaction_point = if seq[1] > 0
		findfirst(x -> x < 0, seq)
	else
		findfirst(x -> x > 0, seq)
	end

	if isnothing(interaction_point)
		interaction_point = length(damping)
		@warn "No interaction point found. Setting interaction point to the end of the damping range."
	end

	# NOTE --- Plot 4: Inertia Bounds and Interaction ---

	# sy1 = plot(
	# 	damping, inertia_updown_bindings[:, 1],
	# 	framestyle = :box,
	# 	ylims = (0, maximum(inertia_updown_bindings[:, 1])),
	# 	xlabel = "Damping (p.u.)",
	# 	ylabel = "Inertia (p.u.)",
	# 	lw = 3,
	# 	label = "Upper Bound",
	# 	# title = "Inertia Bounds",
	# 	legend = :topleft,
	# 	grid = true
	# )
	# plot!(sy1, damping, inertia_updown_bindings[:, 2],
	# 	lw = 3,
	# 	label = "Lower Bound",
	# 	color = :forestgreen
	# )
	# plot!(sy1, damping, inertia_updown_bindings[:, 1],
	# 	fillrange = fillarea,
	# 	fillalpha = 0.3,
	# 	label = "Fill Area",
	# 	color = :skyblue
	# )

	# tem_interaction_point = Int64(interaction_point[1])
	# temp = damping[tem_interaction_point:end], max_inertia[tem_interaction_point:end]
	# plot!(sy1, temp,
	# 	fillrange = fillarea[tem_interaction_point:end],
	# 	fillalpha = 0.5,
	# 	label = "Interaction",
	# 	color = :red
	# )

	# plot!(sy1, damping, fitted_curve,
	# 	lw = 3,
	# 	label = "Fitted Curve",
	# 	color = :purple
	# )
	# hline!(sy1, [min_inertia],
	# 	lw = 3,
	# 	label = "Min Inertia",
	# 	linestyle = :dash
	# )
	# plot!(sy1, damping, max_inertia,
	# 	lw = 3,
	# 	label = "Max Inertia",
	# 	color = :orange
	# )

	sy1 = plot_inertia_distribution_with_bounds_improved(
		interaction_point, damping, inertia_updown_bindings, max_inertia, min_inertia, fillarea, fitted_curve,
	)

	# tem_interaction_point = Int64(interaction_point[1])
	# temp = damping[tem_interaction_point:end], max_inertia[tem_interaction_point:end]

	# l = @layout [
	# 	a{0.2h}    # 上部分占 33% 高度
	# 	b{0.7h}    # 中间部分占 34% 高度
	# 	c{0.1h}
	# ]

	# sy1 = plot(
	# 	plot(
	# 		damping,
	# 		inertia_updown_bindings[:, 1],
	# 		# framestyle = :box,
	# 		ylims = (15, 23),           # 调整上限范围
	# 		yticks = 15:5:20,           # 设置均匀刻度
	# 		xlabel = "",               # 移除 xlabel
	# 		ylabel = "",              # 移除单独的 ylabel
	# 		lw = 3,
	# 		showaxis = :y,
	# 		bottom_margin = -15Plots.px,
	# 		# framestyle = :box,
	# 		label = "Upper Bound",
	# 		legend = :none,      # Changed from false to :none
	# 		grid = true,
	# 	),
	# 	begin
	# 		p2 = plot(
	# 			damping,
	# 			inertia_updown_bindings[:, 1],
	# 			fillrange = fillarea,
	# 			fillalpha = 0.3,
	# 			ylims = (5, 15),         # 保持中间范围
	# 			yticks = 5:2:15,         # 设置均匀刻度
	# 			showaxis = :y,
	# 			bottom_margin = -15Plots.px,
	# 			top_margin = -15Plots.px,
	# 			label = "Fill Area",
	# 			color = :skyblue,
	# 			xlabel = "Damping (p.u.)",
	# 			ylabel = "Inertia (p.u.)",
	# 			grid = true,
	# 		)

	# 		# Add additional layers to p2
	# 		plot!(
	# 			p2,
	# 			temp,
	# 			# max_inertia_temp,
	# 			fillrange = fillarea[tem_interaction_point:end],
	# 			fillalpha = 0.5,
	# 			label = "Interaction",
	# 			color = :red,
	# 		)
	# 		plot!(
	# 			p2,
	# 			damping,
	# 			fitted_curve,
	# 			lw = 3,
	# 			label = "Fitted Curve",
	# 			color = :purple,
	# 		)
	# 		hline!(p2, [min_inertia], lw = 3, label = "Min Inertia", linestyle = :dash)
	# 		plot!(p2, damping, max_inertia, lw = 3, label = "Max Inertia", color = :orange)
	# 		p2
	# 	end,
	# 	plot(
	# 		damping,
	# 		inertia_updown_bindings[:, 2],
	# 		lw = 3,
	# 		ylims = (-2, 5),             # 调整下限范围
	# 		yticks = 0:5:5,             # 设置均匀刻度
	# 		top_margin = -15Plots.px,
	# 		label = "Lower Bound",
	# 		color = :forestgreen,
	# 		xlabel = "Damping (p.u.)",
	# 		ylabel = "",               # 移除单独的 ylabel
	# 		grid = true,
	# 	),
	# 	layout = l,
	# 	size = (400, 300),
	# 	left_margin = 30Plots.px,    # 调整左边距
	# 	ylabel = "Inertia (p.u.)",    # 添加全局 ylabel
	# 	legend = :topright,     # Main plot legend
	# 	legendfontsize = 8,     # Adjust legend font size
	# 	legend_column = 2,       # Arrange legend in 2 columns
	# )

	# --- Combine Plots ---
	p1 = plot(sp2, sp3, sp1, sy1; layout = (2, 2), size = (1000, 800))

	return p1, sy1
end

# Improved function for plotting inertia distribution with bounds
function plot_inertia_distribution_with_bounds_improved(
		interaction_point,
		damping,
		inertia_updown_bindings,
		max_inertia,
		min_inertia,
		fillarea,
		fitted_curve,
)

	# --- Data Preparation ---
	# Ensure interaction_point is an integer index
	# Add error handling or validation if interaction_point might be invalid
	tem_interaction_point = if interaction_point === nothing
		length(damping)
	elseif isa(interaction_point, Integer)
		Int64(interaction_point)
	elseif isa(interaction_point, AbstractVector) && !isempty(interaction_point)
		Int64(first(interaction_point))
	else
		Int64(interaction_point)
	end

	# Check if the index is within bounds
	if !(1 <= tem_interaction_point <= length(damping))
		@warn "Interaction point index ($tem_interaction_point) is out of bounds for damping vector (length $(length(damping))). Adjusting to nearest valid index."
		tem_interaction_point = clamp(tem_interaction_point, 1, length(damping))
		# Depending on the logic, you might want to error out instead:
		# error("Interaction point index ($tem_interaction_point) is out of bounds.")
	end

	# Prepare data slice for interaction plot
	interaction_damping = damping[tem_interaction_point:end]
	max_inertia_vec = isa(max_inertia, AbstractArray) ? vec(max_inertia) : fill(max_inertia, length(damping))
	interaction_max_inertia = max_inertia_vec[tem_interaction_point:end]
	interaction_fillarea = fillarea[tem_interaction_point:end]

	# Extract bounds for clarity
	upper_bound = inertia_updown_bindings[:, 1]
	lower_bound = inertia_updown_bindings[:, 2]

	# --- Plotting Configuration ---
	common_line_width = 2.5 # Consistent line width
	fill_alpha_base = 0.25  # Base fill transparency
	fill_alpha_interaction = 0.45 # Interaction fill transparency
	plot_size = (560, 420) # Slightly larger for better readability
	legend_font_size = 7
	global_ylabel = "Inertia (p.u.)"
	global_xlabel = "Damping (p.u.)"

	# Define y-axis limits and ticks for each segment
	# Consider calculating limits dynamically based on data + padding for robustness
	ylims_top = (15, 21)
	yticks_top = 15:2.5:21 # Adjusted for better spacing
	ylims_mid = (0.25, 15)
	yticks_mid = 0.25:2.5:15 # Adjusted for better spacing
	ylims_bot = (0, 0.25)
	yticks_bot = 0:0.25:0.25 # Adjusted for better spacing

	# Define the layout for the broken axis effect
	# Adjust heights if needed based on data range visualization
	l = @layout [top_ax{0.2h}
				 mid_ax{0.6h}
				 bot_ax{0.2h}]

	# --- Create Subplots ---

	# Top Subplot (Upper part of the range)
	plot_top = plot(
		damping,
		upper_bound;
		ylims = ylims_top,
		yticks = yticks_top,
		label = "Upper Bound",
		lw = common_line_width,
		color = :blue, # Explicit color
		legend = :none,      # No legend for this part
		# framestyle = :box,   # Use box frame
		grid = true,
		gridalpha = 0.3,
		showaxis = :y,       # Only show y-axis line and ticks
		xtickfontcolor = RGBA(0, 0, 0, 0), # Hide x-axis ticks labels (alternative to removing axis)
		bottom_margin = -25Plots.px, # Reduce space below
	)

	# Middle Subplot (Main area of interest)
	plot_middle = plot(
		damping,
		upper_bound; # Plotting upper bound as base for fill
		fillrange = fillarea,
		fillalpha = fill_alpha_base,
		fillcolor = :skyblue, # Feasible region
		label = "Feasible Region", # More descriptive label
		ylims = ylims_mid,
		yticks = yticks_mid,
		lw = 0, # Don't draw the line itself here, just the fill
		color = :skyblue, # Match fill color (though lw=0 hides it)
		legend = :none, # Will be combined later
		# framestyle = :box,
		grid = true,
		gridalpha = 0.3,
		showaxis = :y,
		xtickfontcolor = RGBA(0, 0, 0, 0), # Hide x-axis ticks labels
		bottom_margin = -25Plots.px,
		top_margin = -25Plots.px,
	)

	# Add layers to the middle plot
	plot!(plot_middle, damping, upper_bound; lw = common_line_width, color = :blue, label = "Upper Bound") # Draw upper bound line
	plot!(
		plot_middle,
		interaction_damping,
		interaction_max_inertia;
		fillrange = interaction_fillarea,
		fillalpha = fill_alpha_interaction,
		fillcolor = :gold,
		label = "Intersection Region",
		lw = 0, # Only fill
		color = :gold, # Match fill color
	)
	plot!(
		plot_middle,
		damping,
		fitted_curve;
		lw = common_line_width,
		linestyle = :dot, # Different style for fitted curve
		label = "Fitted Curve",
		color = :purple,
	)
	hline!(
		plot_middle,
		[min_inertia];
		lw = common_line_width,
		label = "Min Inertia",
		linestyle = :dash,
		color = :black, # Clearer color for boundary
	)
	plot!(
		plot_middle,
		damping,
		max_inertia_vec;
		lw = common_line_width,
		label = "Max Inertia",
		color = :orange,
		linestyle = :dashdot, # Different style
	)

	# Bottom Subplot (Lower part of the range)
	plot_bottom = plot(
		damping,
		lower_bound;
		ylims = ylims_bot,
		yticks = yticks_bot,
		label = "Lower Bound",
		lw = common_line_width,
		color = :forestgreen,
		legend = :none,
		# framestyle = :box,
		grid = true,
		gridalpha = 0.3,
		showaxis = :all, # Show both axes here
		xlabel = global_xlabel, # Add x-label only here
		top_margin = -25Plots.px, # Reduce space above
	)

	# --- Combine Subplots ---
	combined_plot = plot(
		plot_top,
		plot_middle,
		plot_bottom;
		layout = l,
		size = plot_size,
		# borderwidth = 10,
		left_margin = 35Plots.px,    # Ensure space for global ylabel
		bottom_margin = 10Plots.px,  # Ensure space for xlabel
		# plot_title = "Inertia Bounds vs. Damping", # Add a title
		link = :x, # Link x-axes for zooming/panning
		# Add global Y label manually via annotation or use PlotAnnotations
		# Simple annotation example:
		annotate = [(-0.12, 0.5, text(global_ylabel, :black, :center, 10; rotation = 90))],
		# Configure the main legend (collects labels from all subplots unless :none)
		# legend = :outertopright, # Place legend outside plot area
		legendfontsize = legend_font_size,        # legend_column = 2, # May not be needed with :outertopright
	)

	return combined_plot
end

# --- IEEE Styling Constants ---
const IEEE_FONT = "serif" # Use a common serif font for academic style
const IEEE_GUIDE_SIZE = 11
const IEEE_TICK_SIZE = 9
const IEEE_LEGEND_SIZE = 8

"""
	plot_ieee_style_feasible_region(droop_parameter::Float64; title_label::String="")

Generates a publication-quality subplot for a given droop parameter.
Calculates the true intersection of all constraints (inertia bounds, stability curve,
RoCoF limits) to visualize the actual convex feasible region.

This function is intended for use in academic publications (IEEE style).
"""
function plot_ieee_style_feasible_region(droop_parameter::Float64; title_label::String = "")
	# 1. Base Plot Configuration
	# Assumes generate_inertia_damping_figure is available or we build it here.
	# For better decoupling, we'll re-calculate and plot explicitly.

	# Extract specific parameters
	controller_config = converter_formming_configuations()
	vsm_params = controller_config["VSM"]["control_parameters"]
	droop_params = controller_config["Droop"]["control_parameters"]

	# Get boundary parameters (flag_converter = 0)
	init_H, fact_C, time_C, _, rocof_T, nadir_T, power_D = get_parmeters(0)

	# Define damping range for sampling
	damping_vals = collect(range(2.0, 15.0; length = 200))

	# 2. Calculate all boundary vectors
	inertia_bounds, extreme_inertia, _, _, _ = calculate_inertia_parameters(
		init_H, fact_C, time_C, droop_parameter, power_D,
		damping_vals, vsm_params, droop_params, 0,
	)
	h_red_scalar, h_orange_vec = estimate_inertia_limits(
		rocof_T, power_D, damping_vals, fact_C, time_C, droop_parameter,
	)
	h_orange = vec(h_orange_vec)
	fit_coeffs = calculate_fittingparameters(extreme_inertia, damping_vals)
	h_purple = @. fit_coeffs[1] + fit_coeffs[2] * damping_vals + fit_coeffs[3] * damping_vals^2

	# 3. Determine Intersection Boundaries
	h_low = max.(inertia_bounds[:, 2], h_red_scalar, h_purple)
	h_up = min.(inertia_bounds[:, 1], h_orange)

	# 4. Initialize Plot with IEEE Aesthetics
	p = plot(;
		fontfamily = IEEE_FONT,
		guidefontsize = IEEE_GUIDE_SIZE,
		tickfontsize = IEEE_TICK_SIZE,
		legendfontsize = IEEE_LEGEND_SIZE,
		grid = true,
		gridalpha = 0.15,
		gridstyle = :dash,
		title = title_label,
		titlefontsize = 12,
		xlabel = "Damping (p.u.)",
		ylabel = "Inertia (p.u.)",
		thickness_scaling = 1.1,
		framestyle = :box,
		xlims = (2.0, 15.0),
		ylims = (0, 22),
	)

	# Plot specific constraint lines
	plot!(p, damping_vals, inertia_bounds[:, 1]; color = :blue, lw = 2, label = "Inertia Upper bound")
	plot!(p, damping_vals, inertia_bounds[:, 2]; color = :blue, lw = 1.5, label = "Inertia Lower bound")
	plot!(p, damping_vals, h_purple; color = :purple, linestyle = :dash, lw = 2, label = "Nadir Stability")
	hline!(p, [h_red_scalar]; color = :red, linestyle = :dot, lw = 2, label = "Min RoCoF limit")
	plot!(p, damping_vals, h_orange; color = :orange, linestyle = :dashdot, lw = 2, label = "Max RoCoF limit")

	# 5. Plot Shaded Feasible Intersection
	feasible_idx = findall(h_low .<= h_up)
	if !isempty(feasible_idx)
		d_p = damping_vals[feasible_idx]
		h_l = h_low[feasible_idx]
		h_u = h_up[feasible_idx]

		poly_x = [d_p; reverse(d_p)]
		poly_y = [h_l; reverse(h_u)]

		hull = chull(hcat(poly_x, poly_y))

		plot!(p, poly_x[hull.vertices], poly_y[hull.vertices];
			seriestype = :shape,
			fillalpha = 0.3,
			fillcolor = :navy,
			linecolor = :black,
			linewidth = 0.8,
			label = "Feasible Region",
			legend = false,)
	end

	return p
end

function draw_hdregions(DROOP_PARAMETERS)
	# 1. Generate Individual Subplots using the centralized IEEE plotting engine
	println("Generating academic subplots...")
	p1 = plot_ieee_style_feasible_region(DROOP_PARAMETERS[1]; title_label = "(a) Droop = $(round(1/DROOP_PARAMETERS[1], digits=3))")
	p2 = plot_ieee_style_feasible_region(DROOP_PARAMETERS[4]; title_label = "(b) Droop = $(round(1/DROOP_PARAMETERS[4], digits=3))")
	p3 = plot_ieee_style_feasible_region(DROOP_PARAMETERS[6]; title_label = "(c) Droop = $(round(1/DROOP_PARAMETERS[6], digits=3))")
	p4 = plot_ieee_style_feasible_region(DROOP_PARAMETERS[10]; title_label = "(d) Droop = $(round(1/DROOP_PARAMETERS[10], digits=3))")

	# 2. Combine into Final Publication Layout
	println("Combining plots into IEEE layout...")
	final_plot = Plots.plot(p1, p2, p3, p4;
		layout = (2, 2),
		size = (800, 700),
		dpi = 600,
		margin = 5Plots.mm,
	)

	# 3. Post-processing: Standardize axis sharing for visual clarity
	plot!(p1; xlabel = "", ylabel = "Inertia (p.u.)")
	plot!(p2; xlabel = "", ylabel = "")
	plot!(p3; xlabel = "Damping (p.u.)", ylabel = "Inertia (p.u.)")
	plot!(p4; xlabel = "Damping (p.u.)", ylabel = "")

	return final_plot, p1, p2, p3, p4
end
