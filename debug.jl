include("src/automatic_workflow.jl")

# Define droop parameters.  Consider moving this to a separate configuration section if needed.
@show droop_parameters = collect(range(33, 40, length = 20))

# Define a function to generate and plot the inertia-damping functions
function plot_inertia_damping(droop_parameters::AbstractVector)
	if isempty(droop_parameters)
		println("Warning: droop_parameters is empty. No plot will be generated.")
		return
	end
	_plot_inertia_damping(droop_parameters)
end

function _plot_inertia_damping(droop_parameters)
	plots = []
	labels = []
	vertexs = []

	for param in droop_parameters
		p, sub_vertexs = get_inertiatodamping_functions(param)

		# Basic error handling: Check if get_inertiatodamping_functions returned valid data
		if p === nothing || sub_vertexs === nothing
			println("Warning: get_inertiatodamping_functions returned nothing for parameter $param. Skipping this parameter.")
			continue
		end

		push!(plots, p)
		push!(labels, "Droop 1/$(round(1 / param, digits = 3))") # Use string interpolation
		push!(vertexs, sub_vertexs)
	end

	@show vertexs

	# Use the splat operator (...) to pass all plots at once
	p1 = Plots.plot(plots...,
		legend = false, size = (1000, 1000),
		xlabel = "Damping", ylabel = "Inertia",
		label = permutedims(labels)) # Use permutedims for correct label orientation

	return p1, vertexs
end

# Call plotting function
p1, vertexs = plot_inertia_damping(droop_parameters)

if !isnothing(p1)
	display(p1) # or save to file using Plots.savefig
end

using LinearAlgebra

# Assuming vertexs is a Vector of matrices, each of size (n, 4)
# where n is the number of vertices for a given parameter

# Convert vertexs to a single matrix
function vertexs_to_matrix(vertexs)
	# Get the total number of points across all sub-vertex arrays
	total_points = sum(size(v, 1) for v in vertexs)

	# Create a matrix with enough rows to hold all points and 4 columns
	matrix = zeros(total_points, 3)

	# Populate the matrix
	current_row = 1
	lll = length(vertexs)
	for sub_vertexs in 1:lll
		num_rows = size(vertexs[sub_vertexs], 1)
		res = [collect(v) for v in vertexs[sub_vertexs]]
		matrix[current_row:(current_row + num_rows - 1), :] = permutedims(hcat(res...))
		current_row += num_rows
	end

	return matrix
end

vertexs_matrix = vertexs_to_matrix(vertexs)

# Display the result
@show vertexs_matrix
