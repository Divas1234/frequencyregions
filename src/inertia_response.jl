# IR stsage
function min_inertia_estimation(
		ROCOF_threshold, delta_p, damping, factorial_coefficient, time_content)

	lower_bound = 0.5 * (delta_p * 100) / (ROCOF_threshold * 50) 
	# lower_bound = 0.5 * (delta_p * 1) / (ROCOF_threshold * 1) 

	ll = length(damping)
	upper_bound = zeros(ll, 1)

	for i in 1:ll
		tem_damping = damping[i]
		upper_bound[i] = (100 / 50) * (droop + tem_damping + factorial_coefficient) * time_content / 2
	end

	return lower_bound, upper_bound
end
