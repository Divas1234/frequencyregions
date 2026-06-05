damping = 1:0.1:10

inertia = 6
# damping = damping[i]
factorial_coefficient = 0.27
time_content = 0.25
droop = 0.6
# damping = 0.8

function inertia_damping_relations(
		damping, factorial_coefficient, time_content, droop)
	str1 = sqrt(time_content * (damping - factorial_coefficient))
	term1 = (str1 + 1)^2 + time_content * (droop + factorial_coefficient) - 1
	term2 = sqrt(time_content * (droop - factorial_coefficient))

	upper_bound_1 = term1 + term2
	lower_bound_1 = term1 - term2
	lower_bound_2 = term2 - term1
	upper_bound_2 = sqrt(time_content * (damping + factorial_coefficient))
	return upper_bound_1, lower_bound_1, lower_bound_2, upper_bound_2
	return upper_bound_1, lower_bound_1, lower_bound_2, upper_bound_2
	
end

damping = 0.6:0.1:5
res = zeros(size(damping, 1), 4)

# i = 14
# println(i)
# upper_bound_1, lower_bound_1, lower_bound_2, upper_bound_2 = inertia_damping_relations(
# inertia, damping[i], factorial_coefficient, time_content, droop)
for i in eachindex(damping)
	println(i)
	upper_bound_1, lower_bound_1, lower_bound_2, upper_bound_2 = inertia_damping_relations(
		damping[i], factorial_coefficient, time_content, droop)
	res[i, 1] = upper_bound_1^2
	res[i, 2] = lower_bound_1^2
	res[i, 3] = lower_bound_2^2
	res[i, 4] = upper_bound_2^2
end

using Plots
plot(damping, res[:, 1], lw = 2, label = "upper_bound_1")
plot!(damping, res[:, 2], lw = 2, label = "lower_bound_1")
plot!(damping, res[:, 3], lw = 2, label = "lower_bound_2")
plot!(damping, res[:, 4], lw = 2, label = "upper_bound_2")
