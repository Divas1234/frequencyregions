include("environment_config.jl")

# --- sudmodule Script Execution ---

function get_inertiatodamping_functions(droop_parameters)

	# converter_formming_configuations
	controller_config = converter_formming_configuations()

	flag_converter = Int64(0)

	converter_vsm_parameters = get(controller_config, "VSM", Dict())["control_parameters"]
	converter_droop_parameters = get(controller_config, "Droop", Dict())["control_parameters"]

	# Get parameters from boundary conditions
	initial_inertia, factorial_coefficient, time_constant, droop, ROCOF_threshold, NADIR_threshold, power_deviation = get_parmeters(flag_converter)

	droop = droop_parameters

	# Calculate inertia parameters

	inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids = calculate_inertia_parameters(
		initial_inertia, factorial_coefficient, time_constant, droop, power_deviation,
		DAMPING_RANGE, converter_vsm_parameters, converter_droop_parameters, flag_converter)

	# Estimate inertia limits
	min_inertia, max_inertia = estimate_inertia_limits(
		ROCOF_threshold, power_deviation, DAMPING_RANGE, factorial_coefficient, time_constant, droop
	)

	p1, vertexs = sub_data_visualization(
		DAMPING_RANGE, min_inertia, max_inertia, inertia_updown_bindings,
		extreme_inertia, nadir_vector, inertia_vector, selected_ids)

	# p1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia,
	# 	nadir_vector, inertia_vector, selected_ids)

	return p1, vertexs
end

function sub_data_visualization(
		damping, min_inertia, max_inertia, inertia_updown_bindings, extreme_inertia,
		nadir_vector, inertia_vector, selected_ids)

	# NOTE type functions: c + b * damping a * damping^2

	fittingparameters = calculate_fittingparameters(extreme_inertia, damping)

	fillarea = zeros(length(damping))
	for i in eachindex(damping)
		str = fittingparameters[1] .+ fittingparameters[2] .* damping[i] .+
			  fittingparameters[3] .* damping[i] .^ 2
		if str > min_inertia
			fillarea[i] = str
		else
			fillarea[i] = min_inertia
		end
	end

	@show seq = fittingparameters[1] .+ fittingparameters[2] .* damping .+
				fittingparameters[3] .* damping .^ 2 .- max_inertia

	# if seq[1] > 0
	# 	interaction_point = findfirst(x -> x < 0, seq)[1]
	# else
	# 	interaction_point = findfirst(x -> x > 0, seq)[1]
	# end

	sy1 = Plots.plot(
		damping, inertia_updown_bindings[:, 1], framestyle = :box,
		ylims = (0, maximum(inertia_updown_bindings[:, 1])),
		xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", lw = 3, label = "upper_bound_1",
		title = "Inertia Bounds", legend = true)
	sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 2], lw = 3,
		label = "lower_bound_2", color = :forestgreen)

	# sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 1], fillrange = fillarea,
	# fillalpha = 0.3, label = "", color = :skyblue)

	# sy1 = Plots.plot!(
	# 	damping[interaction_point:end], max_inertia[interaction_point:end],
	# 	fillrange = fillarea[interaction_point:end],
	# 	fillalpha = 0.5, label = "Interaction", color = :red)
	# sy1 = Plots.plot(damping, extreme_inertia, lw = 2, label = "extreme_inertia");

	sy1 = Plots.plot!(damping, lw = 3,
		fittingparameters[1] .+ fittingparameters[2] .* damping .+
		fittingparameters[3] .* damping .^ 2)
	sy1 = Plots.hline!([min_inertia], lw = 3, label = "min_inertia")
	sy1 = Plots.plot!(damping, max_inertia, lw = 3, label = "max_inertia")

	# add additional information
	sy1 = Plots.vline!([12.0], lw = 3, label = "damping_min_binding")
	sy1 = Plots.vline!([2.5], lw = 3, label = "damping_max_binding")

	vertexs = calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
		min_inertia, max_inertia, min_damping, max_damping)

	return sy1, vertexs
end

function calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
		min_inertia, max_inertia, min_damping, max_damping)
	ids_1 = findfirst(x -> x > max_damping, DAMPING_RANGE)
	vertex_1 = (droop, DAMPING_RANGE[ids_1], min_inertia)
	vertex_2 = (droop, DAMPING_RANGE[ids_1], max_inertia[ids_1])
	ids_2 = findfirst(x -> x > min_damping, DAMPING_RANGE)
	vertex_3 = (droop, DAMPING_RANGE[ids_2], max_inertia[ids_2])
	vertex_4 = (droop, DAMPING_RANGE[ids_2], min_inertia)
	tem_sequence = fittingparameters[1] .+ fittingparameters[2] .* damping .+
				   fittingparameters[3] .* damping .^ 2
	vertex_5 = (droop, DAMPING_RANGE[ids_2], tem_sequence[ids_2])

	res = []
	if vertex_4 > vertex_5
		res = [vertex_2; vertex_1; vertex_4; vertex_3]
	else
		ids_3 = findfirst(x -> x < min_inertia, tem_sequence) - 1
		vertex_6 = (droop, DAMPING_RANGE[ids_3], min_inertia)
		if vertex_3 > vertex_5
			res = [vertex_2; vertex_1; vertex_6; vertex_5; vertex_3]
		else
			ids_4 = findfirst(x -> x < 0, tem_sequence - max_inertia) - 1
			vertex_7 = (droop, DAMPING_RANGE[ids_4], tem_sequence[ids_4])
			res = [vertex_2; vertex_1; vertex_6; vertex_7]
		end
	end
	return res
end
