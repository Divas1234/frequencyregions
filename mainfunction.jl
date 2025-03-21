include("src/environment_config.jl")

# Get parameters from boundary conditions
initial_inertia, factorial_coefficient, time_content, droop, ROCOF_threshold, NADIR_threshold, delta_p = get_parmeters()
damping = 0.5:0.25:15

# zeta smaller than 1
inertia_updown_bindings = inertia_bindings(damping, factorial_coefficient, time_content, droop)
DataFrames.DataFrame(inertia_updown_bindings, :auto)
@assert inertia_updown_bindings[:, 1] > inertia_updown_bindings[:, 2]

extreme_inertia, nadir_vector, inertia_vector, selected_ids = generate_extreme_inertia(
	initial_inertia, factorial_coefficient, time_content, droop,
	delta_p, damping, inertia_updown_bindings)

@show DataFrames.DataFrame(extreme_inertia, :auto)

# inertia_response,time-to-frequency nadir larger than zeros
min_inertia, max_inertia = min_inertia_estimation(
	ROCOF_threshold, delta_p, damping, factorial_coefficient, time_content, droop)

p1 = data_visualization(damping, inertia_updown_bindings, extreme_inertia,
	nadir_vector, inertia_vector, selected_ids)
