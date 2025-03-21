# FR stage
function inertia_bindings(damping, factorial_coefficient, time_content, droop)
	tem = zeros(length(damping), 2)
	for i in eachindex(damping)
		upper_bound_1, lower_bound_1 = inertia_damping_relations(
			damping[i], factorial_coefficient, time_content, droop)
		tem[i, 1] = upper_bound_1
		tem[i, 2] = lower_bound_1
	end
	@assert tem[:, 1] > tem[:, 2]
	return tem
end

function inertia_damping_relations(
		damping, factorial_coefficient, time_content, droop)

	# version 1
	# str1 = sqrt(time_content * (damping - factorial_coefficient))
	# term1 = (str1 + 1)^2 + time_content * (droop + factorial_coefficient) - 1
	# term2 = sqrt(time_content * (droop - factorial_coefficient))

	# upper_bound_1 = term1 + term2
	# lower_bound_1 = term1 - term2
	# lower_bound_2 = term2 - term1
	# upper_bound_2 = sqrt(time_content * (damping + factorial_coefficient))

	# version 2
	tem1 = (damping - factorial_coefficient + 2 * droop)
	tem2 = tem1^2 - (damping + factorial_coefficient)^2

	@assert tem2 >= 0
	@assert droop > factorial_coefficient

	lower_bound_1 = time_content * (tem1 - sqrt(tem2)) / 2
	upper_bound_1 = time_content * (tem1 + sqrt(tem2)) / 2

	# plot(damping, res[:, 1], lw = 2, label = "upper_bound_1")
	# plot!(damping, res[:, 2], lw = 2, label = "lower_bound_1")
	# plot!(damping, res[:, 3], lw = 2, label = "lower_bound_2")
	# plot!(damping, res[:, 4], lw = 2, label = "upper_bound_2")
	# # vline!([2.5], lw = 2, label = "damping = 2.5", linestyle = :dash)
	# hline!([res[1, 5]], lw = 2, label = "damping = 2.5", linestyle = :dash)

	return upper_bound_1, lower_bound_1
end
