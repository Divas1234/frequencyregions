include("src/automatic_workflow.jl")

# Define a function to generate and plot the inertia-damping functions
function plot_inertia_damping(droop_parameters)
	if isempty(droop_parameters)
		println("Warning: droop_parameters is empty. No plot will be generated.")
		return
	end

	plots = []
	labels = []

	for param in droop_parameters
		p, vertexs = get_inertiatodamping_functions(param)
		push!(plots, p)
		push!(labels, "Droop 1/" * string(round(1 / param, digits = 3))) # Create labels dynamically and round for better display
	end

	# Use the splat operator (...) to pass all plots at once
	Plots.plot(plots...,
		legend = false, size = (1000, 1000),
		xlabel = "Damping", ylabel = "Inertia",
		label = permutedims(labels)) # Use permutedims for correct label orientation
end

# Define droop parameters

@show droop_parameters = collect(range(33, 40, length = 20))

# Call plotting function
plot_inertia_damping(droop_parameters)
