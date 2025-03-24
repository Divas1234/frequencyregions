include("src/automatic_workflow.jl")

droop_parameters = 1 / 0.03
# p1. vertexs = get_inertiatodamping_functions(droop_parameters)

# DEBUG: vertexs

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

fittingparameters = calculate_fittingparameters(extreme_inertia, DAMPING_RANGE)

# FIXME - this section

min_damping,max_damping = 2.5,12

ids_1 = findfirst(x -> x > max_damping, DAMPING_RANGE)
vertex_1 = (droop, DAMPING_RANGE[ids_1], min_inertia)
vertex_2 = (droop, DAMPING_RANGE[ids_1], max_inertia[ids_1])
ids_2 = findfirst(x -> x > min_damping, DAMPING_RANGE)
vertex_3 = (droop, DAMPING_RANGE[ids_2], max_inertia[ids_2])
vertex_4 = (droop, DAMPING_RANGE[ids_2], min_inertia)
tem_sequence = fittingparameters[1] .+ fittingparameters[2] .* DAMPING_RANGE .+
			   fittingparameters[3] .* DAMPING_RANGE .^ 2
vertex_5 = (droop, DAMPING_RANGE[ids_2], tem_sequence[ids_2])

vertex_4[3] > vertex_5[3]
[vertex_2; vertex_1; vertex_4; vertex_3]
ids_3 = findfirst(x -> x < min_inertia, tem_sequence) - 1
	vertex_6 = (droop, DAMPING_RANGE[ids_3], min_inertia)
	ids_4 = findfirst(x -> x < 0, tem_sequence - max_inertia)[1] - 1

res = []
if vertex_4[3] > vertex_5[3] #nadir constraints is below the min_inertia bindings
	res = [vertex_2; vertex_1; vertex_4; vertex_3]
else # nadier constraints is above the min_inertia bindings
       ids_3 = findfirst(x -> x < min_inertia, tem_sequence) - 1 # the interaction point between the nadier fitting curve and  the min_inertia bindings
	vertex_6 = (droop, DAMPING_RANGE[ids_3], min_inertia)
	if vertex_3 > vertex_5
		res = [vertex_2; vertex_1; vertex_6; vertex_5; vertex_3] # the nadir constraints is below than the max_inertia bindings
	else
		ids_4 = findfirst(x -> x < 0, tem_sequence - max_inertia)[1] - 1 
		vertex_7 = (droop, DAMPING_RANGE[ids_4], tem_sequence[ids_4])
		res = [vertex_2; vertex_1; vertex_6; vertex_7]
	end
end