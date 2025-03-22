include("src/environment_config.jl")

# --- Main Script Execution ---

# converter_formming_configuations
controller_config = converter_formming_configuations()

flag_converter = Int64(0)

# 提取 vsm 参数
converter_vsm_parameters = get(controller_config, "VSM", Dict())["control_parameters"]
converter_droop_parameters = get(controller_config, "Droop", Dict())["control_parameters"]

# Get parameters from boundary conditions
initial_inertia, factorial_coefficient, time_constant, droop, ROCOF_threshold, NADIR_threshold, power_deviation = get_parmeters(flag_converter)

# Calculate inertia parameters

inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids = calculate_inertia_parameters(
	initial_inertia, factorial_coefficient, time_constant, droop, power_deviation,
	DAMPING_RANGE, converter_vsm_parameters, converter_droop_parameters, flag_converter)

# Estimate inertia limits
min_inertia, max_inertia = estimate_inertia_limits(
	ROCOF_threshold, power_deviation, DAMPING_RANGE, factorial_coefficient, time_constant, droop
)

# Data visualization
damping = DAMPING_RANGE
sp1 = Plots.plot(
	damping, extreme_inertia, lw = 3, framestyle = :box, ylims = (
		0, maximum(extreme_inertia)),
	xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", title = "Extreme Inertia", legend = true);
sp1 = Plots.plot!(damping, extreme_inertia, fillrange = inertia_updown_bindings[:, 1],
	fillalpha = 0.3, label = "", color = :skyblue);
sp2 = heatmap(nadir_vector, framestyle = :box, xlabel = "Damping",
	ylabel = "nadir distribution", title = "Nadir Distribution");
sp3 = heatmap(inertia_vector, framestyle = :box,
	xlabel = "Damping", ylabel = "inertia distribution", title = "Inertia Distribution");
# Plots.plot!(sp2, sp3, sp1, layout = (2, 2), size = (800, 600))	
sy1 = Plots.plot(
	damping, inertia_updown_bindings[:, 1], framestyle = :box,
	ylims = (0, maximum(inertia_updown_bindings[:, 1])),
	xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", lw = 3, label = "upper_bound_1",
	title = "Inertia Bounds", legend = true);
sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 2], lw = 3,
	label = "lower_bound_2", color = :forestgreen);
# sy1 = Plots.plot(damping, extreme_inertia, lw = 2, label = "extreme_inertia");
sy1 = Plots.hline!([min_inertia], lw = 3, label = "min_inertia");
sy1 = Plots.plot!(damping, max_inertia, lw = 3, label = "max_inertia");
fittingparameters = calculate_fittingparameters(extreme_inertia, damping);
sy1 = Plots.plot!(damping, lw = 3,
	fittingparameters[1] .+ fittingparameters[2] .* damping .+
	fittingparameters[3] .* damping .^ 2);

p1 = plot(sp2, sp3, sp1, sy1, layout = (2, 2), size = (800, 600))
# ----------------------------------------------------------------

# p1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia,
# 	nadir_vector, inertia_vector, selected_ids)

# println("Calculations complete. Plot generated.")
