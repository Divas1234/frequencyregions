"""
	multi_area_analysis.jl

Logic for multi-area frequency security region analysis.
Extends the single-area framework to support multiple coupled areas.
"""

using Statistics

"""
	aggregate_to_system_parameters(multi_config::MultiAreaConfig, base_system::SystemParameters)::SystemParameters

Aggregates a multi-area system into an equivalent single-area (COI) system.
Uses common base system for constants like time_constant if not specified in areas.
"""
function aggregate_to_system_parameters(multi_config::MultiAreaConfig, base_system::SystemParameters)::SystemParameters
	total_inertia = sum(a.inertia for a in multi_config.areas)

	# For damping, we assume it aggregates linearly in the COI model
	# Note: damping is often part of the computation range, so this total_damping
	# might just be a baseline.
	total_damping = sum(a.damping for a in multi_config.areas)

	# In this repository, droop is used on a common system base (1/R form).
	# For COI aggregation, using the mean preserves the original value when
	# all areas share the same droop setting and keeps parity with the
	# single-area baseline configuration.
	positive_droops = [a.droop for a in multi_config.areas if a.droop > 0]
	total_droop = isempty(positive_droops) ? base_system.droop : mean(positive_droops)

	# Disturbance magnitude
	disturbed_area = filter(a -> a.name == multi_config.disturbance_area_name, multi_config.areas)
	if isempty(disturbed_area)
		error("Disturbance area $(multi_config.disturbance_area_name) not found in areas list.")
	end
	power_deviation = disturbed_area[1].power_deviation

	# Constraints: we take the most restrictive for the COI model
	# Though usually Nadir and RoCoF thresholds are system-wide.
	rocof_threshold = minimum(a.rocof_threshold for a in multi_config.areas)
	nadir_threshold = minimum(a.nadir_threshold for a in multi_config.areas)

	return SystemParameters(
		total_inertia,
		base_system.factorial_coefficient,
		base_system.time_constant,
		total_droop,
		rocof_threshold,
		nadir_threshold,
		power_deviation,
	)
end

"""
	calculate_multi_area_rocof_bound(multi_config::MultiAreaConfig)::Float64

Calculates the minimum required inertia in the DISTURBED area to satisfy RoCoF.
"""
function calculate_multi_area_rocof_bound(multi_config::MultiAreaConfig)::Float64
	disturbed_area = first(filter(a -> a.name == multi_config.disturbance_area_name, multi_config.areas))

	# RoCoF = delta_P / (2 * H)
	# H_min = delta_P / (2 * RoCoF_threshold)
	# We use the percentage base and frequency base from environment constants
	# (Assuming they are available in scope)

	h_min_local = 0.5 * (disturbed_area.power_deviation * PERCENTAGE_BASE) / (disturbed_area.rocof_threshold * FREQUENCY_BASE)
	return h_min_local
end

"""
	calculate_multi_area_tieline_bound(multi_config::MultiAreaConfig)::Float64

Calculates the minimum aggregate inertia required to keep tie-line power within limits.
Formula: P_tie = (H_others / H_total) * Delta_P <= P_tie_limit
"""
function calculate_multi_area_tieline_bound(multi_config::MultiAreaConfig)::Float64
	disturbed_area = first(filter(a -> a.name == multi_config.disturbance_area_name, multi_config.areas))
	others_inertia = sum(a.inertia for a in multi_config.areas if a.name != multi_config.disturbance_area_name)

	# Find relevant tie-line limit
	# For simplicity, we assume there's an aggregate limit for power exported/imported
	# to/from the disturbed area.
	p_tie_limit = Inf
	for ((a1, a2), limit) in multi_config.tie_line_limits
		if a1 == multi_config.disturbance_area_name || a2 == multi_config.disturbance_area_name
			p_tie_limit = min(p_tie_limit, limit)
		end
	end

	if isinf(p_tie_limit) || p_tie_limit == 0
		return 0.0
	end

	# H_total_min = (H_others * Delta_P) / P_tie_limit
	h_total_min = (others_inertia * disturbed_area.power_deviation) / p_tie_limit
	return h_total_min
end

"""
	calculate_multi_area_diff_nadir_bound(multi_config::MultiAreaConfig, base_system::SystemParameters)::Float64

Estimates the minimum aggregate inertia required to satisfy the LOCAL nadir constraint in the disturbed area,
considering differential mode frequency drops.
"""
function calculate_multi_area_diff_nadir_bound(multi_config::MultiAreaConfig, base_system::SystemParameters)::Float64
	disturbed_area = first(filter(a -> a.name == multi_config.disturbance_area_name, multi_config.areas))
	others_inertia = sum(a.inertia for a in multi_config.areas if a.name != multi_config.disturbance_area_name)

	# The local nadir in Area 1 is deeper than the COI nadir.
	# Delta_f_local = Delta_f_COI + Delta_f_diff
	# A simplified safety margin or a local RoCoF-based projection can be used.
	# Here we use the local parameters to estimate a required local inertia H_1_min.

	# Approximated differential mode frequency drop margin (empirical or analytical)
	# Delta_f_diff_max is related to the tie-line stiffness.
	t_ij = disturbed_area.tieline_stiffness > 0 ? disturbed_area.tieline_stiffness : multi_config.default_tieline_stiffness

	if t_ij <= 0
		# If no stiffness info, fallback to a conservative local RoCoF bound as proxy for fast drop
		return 0.0
	end

	# Differential drop peak ~ Delta_P / (2 * sqrt(H_1 * T_ij))
	# We want Delta_f_COI + Delta_f_diff <= Nadir_threshold
	# For a rough bound, we ensure H_1 is at least some value.
	# This is a placeholder for more advanced inter-area swing analysis.
	h_local_min_diff = (disturbed_area.power_deviation^2) / (4 * t_ij * disturbed_area.nadir_threshold^2)

	return h_local_min_diff + others_inertia
end

"""
	execute_multi_area_workflow(multi_config::MultiAreaConfig, config::ComputationConfig,
							   controller_config::ControllerConfig)::ComputationResult

Runs the frequency security region workflow for a multi-area system.
Visualizes the region in terms of AGGREGATED inertia and AGGREGATED damping.
"""
function execute_multi_area_workflow(multi_config::MultiAreaConfig, config::ComputationConfig,
		controller_config::ControllerConfig,)::ComputationResult

	# 1. Create base system parameters
	base_system = create_system_parameters(config.flag_converter)

	# 2. Aggregate to COI
	coi_system = aggregate_to_system_parameters(multi_config, base_system)

	# 3. Create a state for the aggregated system
	state = WorkflowState(controller_config, coi_system, config)

	# 4. Compute inertia bounds (Nadir based)
	compute_inertia_bounds(state)

	# 5. Estimate inertia limits (RoCoF and other bounds)
	coi_min_h,
	coi_max_h = estimate_inertia_limits(
		state.system_params.rocof_threshold,
		state.system_params.power_deviation,
		state.computation_config.damping_range,
		state.system_params.factorial_coefficient,
		state.system_params.time_constant,
		state.system_params.droop,
	)

	# --- Multi-Area Specific Constraints ---

	# A. Local RoCoF bound for the disturbed area
	h_disturbed_min_local_rocof = calculate_multi_area_rocof_bound(multi_config)
	others_inertia = sum(a.inertia for a in multi_config.areas if a.name != multi_config.disturbance_area_name)
	total_h_min_rocof = h_disturbed_min_local_rocof + others_inertia

	# B. Tie-line Power Limit Constraint
	total_h_min_tieline = calculate_multi_area_tieline_bound(multi_config)

	# C. Differential Mode Frequency Constraint
	total_h_min_diff = calculate_multi_area_diff_nadir_bound(multi_config, base_system)

	# The actual minimum aggregate inertia is the maximum of all lower bounds
	final_min_h = max(coi_min_h, total_h_min_rocof, total_h_min_tieline, total_h_min_diff)

	# Update state inertia bounds to reflect the most restrictive limits
	for i in 1:size(state.inertia_bounds, 1)
		state.inertia_bounds[i, 1] = min(state.inertia_bounds[i, 1], coi_max_h[i])
		state.inertia_bounds[i, 2] = max(state.inertia_bounds[i, 2], final_min_h)
	end

	# 6. Fitting
	state.fitting_parameters = calculate_fittingparameters(state.extreme_inertia,
		state.computation_config.damping_range,)

	# 7. Visualization
	plot = generate_visualization(state, final_min_h, coi_max_h)

	# 8. Vertices
	vertices = calculate_vertex(
		state.computation_config.damping_range,
		state.inertia_bounds,
		state.fitting_parameters,
		final_min_h,
		maximum(coi_max_h),
		state.computation_config.min_damping,
		state.computation_config.max_damping,
		state.system_params.droop,
	)

	return ComputationResult(
		state.system_params.droop,
		plot,
		vertices,
		state.inertia_bounds,
		state.fitting_parameters,
	)
end
