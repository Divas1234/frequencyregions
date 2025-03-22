function data_visualization(damping, inertia_updown_bindings, extreme_inertia,
		nadir_vector, inertia_vector, selected_ids)

	#TODO NOTE -  plot
	sp1 = Plots.plot(
		damping, extreme_inertia, lw = 3, framestyle = :box, ylims = (0, maximum(extreme_inertia)),
		xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", title = "Extreme Inertia", legend = true)
	sp1 = Plots.plot!(damping, extreme_inertia, fillrange = inertia_updown_bindings[:, 1],
		fillalpha = 0.3, label = "", color = :skyblue)
	sp2 = heatmap(nadir_vector, framestyle = :box, xlabel = "Damping",
		ylabel = "nadir distribution", title = "Nadir Distribution")
	sp3 = heatmap(inertia_vector, framestyle = :box,
		xlabel = "Damping", ylabel = "inertia distribution", title = "Inertia Distribution")

	# #! type functions: c + b * damping a * damping^2
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
	if seq[1] > 0
		interaction_point = findfirst(x -> x < 0, seq)[1]
	else
		interaction_point = findfirst(x -> x > 0, seq)[1]
	end

	sy1 = Plots.plot(
		damping, inertia_updown_bindings[:, 1], framestyle = :box,
		ylims = (0, maximum(inertia_updown_bindings[:, 1])),
		xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", lw = 3, label = "upper_bound_1",
		title = "Inertia Bounds", legend = true)
	sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 2], lw = 3,
		label = "lower_bound_2", color = :forestgreen)
	sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 1], fillrange = fillarea,
		fillalpha = 0.3, label = "", color = :skyblue)

	sy1 = Plots.plot!(damping[interaction_point:end], max_inertia[interaction_point:end],
		fillrange = fillarea[interaction_point:end],
		fillalpha = 0.5, label = "Interaction", color = :red)
	# sy1 = Plots.plot(damping, extreme_inertia, lw = 2, label = "extreme_inertia");
	sy1 = Plots.plot!(damping, lw = 3,
		fittingparameters[1] .+ fittingparameters[2] .* damping .+
		fittingparameters[3] .* damping .^ 2)
	sy1 = Plots.hline!([min_inertia], lw = 3, label = "min_inertia")
	sy1 = Plots.plot!(damping, max_inertia, lw = 3, label = "max_inertia")

	p1 = plot(sp2, sp3, sp1, sy1, layout = (2, 2), size = (800, 600))

	return p1
end
