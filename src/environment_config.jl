using Pkg
Pkg.activate(".Pkg/")
using Plots, PlotThemes
using LinearAlgebra

gr()
# theme(:wong2)

# ===== Core Computation Modules =====
include("boundary.jl")
include("inertia_response.jl")
include("primary_frequencyresponse.jl")
include("analytical_systemfrequencyresponse.jl")
include("inertia_damping_regressionrelations.jl")
include("visulazations.jl")
include("converter_config.jl")
include("generate_geometries.jl")
include("tem_plot_polygonfigures.jl")

# ===== Refactored Modules for Better Maintainability =====
include("config_structures.jl")
include("validation.jl")

# ===== Workflow Orchestration and Functions =====
# Include visualization and vertex calculation functions
# (must come before workflow_orchestrator which calls them)
include("workflow_orchestrator.jl")

# ===== Legacy Workflow Functions (for compatibility) =====
# These functions are needed for visualization in sub_data_visualization
function sub_data_visualization(
		damping, min_inertia, max_inertia, inertia_updown_bindings,
		extreme_inertia, nadir_vector, inertia_vector, selected_ids, min_damping, max_damping, droop, fittingparameters,)

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

	# Ensure inertia_updown_bindings is properly formatted
	bounds_mat = collect(inertia_updown_bindings)
	if size(bounds_mat, 2) != 2
		throw(DimensionMismatch("inertia_updown_bindings must have 2 columns"))
	end
	
	try
		sy1 = Plots.plot(
			collect(damping), bounds_mat[:, 1]; 
			framestyle = :box,
			ylims = (0, maximum(bounds_mat[:, 1])),
			xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", 
			lw = 3, label = "upper_bound",
		)
		
		sy1 = Plots.plot!(collect(damping), bounds_mat[:, 2]; 
			lw = 3,
			label = "lower_bound", color = :forestgreen)

		sy1 = Plots.plot!(collect(damping), 
			fittingparameters[1] .+ fittingparameters[2] .* damping .+
			fittingparameters[3] .* damping .^ 2; 
			lw = 3, label = "fit_curve")
		
		sy1 = Plots.hline!([min_inertia]; lw = 3, label = "min_inertia")
		
		# Convert max_inertia to vector if needed
		max_inertia_vec = isa(max_inertia, AbstractArray) ? vec(max_inertia) : [max_inertia]
		if length(max_inertia_vec) > 1
			sy1 = Plots.plot!(collect(damping), max_inertia_vec; lw = 3, label = "max_inertia")
		else
			sy1 = Plots.hline!(max_inertia_vec; lw = 3, label = "max_inertia")
		end

		sy1 = Plots.vline!([12.0]; lw = 3, label = "damping_min_binding")
		sy1 = Plots.vline!([2.5]; lw = 3, label = "damping_max_binding")
		
		return sy1
	catch e
		@warn "Error in sub_data_visualization: $e"
		# Return a simple fallback plot
		return Plots.plot(collect(damping), bounds_mat[:, 1]; label = "upper_bound")
	end
end

function calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
		min_inertia, max_inertia, min_damping, max_damping, droop,)

	if length(fittingparameters) < 3
		error("fittingparameters must have at least 3 elements")
	end
	if isempty(DAMPING_RANGE)
		error("DAMPING_RANGE cannot be empty")
	end

	function find_damping_index(predicate, damping_range)
		index = findfirst(predicate, damping_range)
		if index === nothing
			# If no exact match, return the closest index
			return length(damping_range)
		end
		return index
	end

	# Find indices for max and min damping - use >= and <= for boundaries
	max_damping_index_raw = findfirst(x -> x >= max_damping, DAMPING_RANGE)
	min_damping_index_raw = findfirst(x -> x >= min_damping, DAMPING_RANGE)
	
	max_damping_index = isnothing(max_damping_index_raw) ? length(DAMPING_RANGE) : max_damping_index_raw
	min_damping_index = isnothing(min_damping_index_raw) ? length(DAMPING_RANGE) : min_damping_index_raw

	function calculate_tem_sequence(fitting_params, damping_range)
		return fitting_params[1] .+ fitting_params[2] .* damping_range .+
			   fitting_params[3] .* damping_range .^ 2
	end

	function create_vertex(droop, damping, inertia)
		return (droop, damping, inertia)
	end

	max_damping_value = DAMPING_RANGE[max_damping_index]
	min_damping_value = DAMPING_RANGE[min_damping_index]

	vertex_max_damping_min_inertia = create_vertex(droop, max_damping_value, min_inertia)
	vertex_max_damping_max_inertia = create_vertex(
		droop, max_damping_value, inertia_updown_bindings[max_damping_index, 1],
	)

	vertex_min_damping_min_inertia = create_vertex(droop, min_damping_value, min_inertia)
	vertex_min_damping_max_inertia = create_vertex(
		droop, min_damping_value, inertia_updown_bindings[min_damping_index, 1],
	)

	tem_sequence = calculate_tem_sequence(fittingparameters, DAMPING_RANGE)
	interaction_index_1 = findfirst(x -> x > min_inertia, tem_sequence)
	interaction_index_2 = findlast(x -> x < maximum(max_inertia), tem_sequence)

	vertexs = []
	push!(vertexs, vertex_max_damping_min_inertia)
	push!(vertexs, vertex_max_damping_max_inertia)

	if !isnothing(interaction_index_1) && !isnothing(interaction_index_2)
		push!(
			vertexs,
			create_vertex(
				droop, DAMPING_RANGE[interaction_index_1], fittingparameters[1] .+ fittingparameters[2] .* DAMPING_RANGE[interaction_index_1] .+ fittingparameters[3] .* DAMPING_RANGE[interaction_index_1] .^ 2,
			),
		)
		push!(
			vertexs,
			create_vertex(
				droop, DAMPING_RANGE[interaction_index_2], fittingparameters[1] .+ fittingparameters[2] .* DAMPING_RANGE[interaction_index_2] .+ fittingparameters[3] .* DAMPING_RANGE[interaction_index_2] .^ 2,
			),
		)
	end

	push!(vertexs, vertex_min_damping_max_inertia)
	push!(vertexs, vertex_min_damping_min_inertia)

	return vertexs
end

function vertices_to_matrix(vertices::AbstractVector)
	# Handle the edge case of an empty vertices array.
	if isempty(vertices)
		@warn "Input 'vertices' is empty. Returning an empty matrix."
		return Matrix{Float64}(undef, 0, 3)
	end

	# Check if first element is a vector or tuple
	first_element = first(vertices)
	
	# If first_element is a vector of tuples (from a single droop result)
	if isa(first_element, AbstractVector) && !isempty(first_element) && isa(first(first_element), Tuple)
		# all_vertices format: [result1_vertices, result2_vertices, ...]
		# where each result_vertices = [(d1,da1,i1), (d2,da2,i2), ...]
		
		first_tuple_length = length(first(first_element))
		if first_tuple_length != 3
			@error "Tuples in 'vertices' must have length 3 (droop, damping, inertia)."
			return nothing
		end

		# Pre-allocate the matrix with the correct size and type.
		total_points = sum(length(v) for v in vertices)
		matrix = Matrix{Float64}(undef, total_points, 3)

		# Populate the matrix efficiently.
		current_row = 1
		for sub_vertices in vertices
			num_rows = length(sub_vertices)
			for (i, vertex) in enumerate(sub_vertices)
				matrix[current_row + i - 1, :] = collect(vertex)
			end
			current_row += num_rows
		end

		return matrix
	else
		@error "Input 'vertices' must be a vector of vectors of tuples."
		return nothing
	end
end

function write_vertices_to_file(matrix::Matrix, base_path::String, rel_path::String)
	# Create the output directory if it doesn't exist
	output_dir = dirname(joinpath(base_path, rel_path))
	if !isdir(output_dir)
		mkpath(output_dir)
	end

	# Get the full output path
	output_file = joinpath(base_path, rel_path)

	# Write the matrix to the file
	open(output_file, "w") do io
		for row in eachrow(matrix)
			println(io, join(row, "\t"))
		end
	end

	println("Vertices saved to: $output_file")
end

# ===== Global Constants =====
const DAMPING_RANGE = 2:0.25:15
const MIN_DAMPING = minimum(DAMPING_RANGE)
const MAX_DAMPING = maximum(DAMPING_RANGE)

# Constants for the formulas
const PERCENTAGE_BASE = 100
const FREQUENCY_BASE = 50
current_filepath = pwd()
# const OUTPUT_REL_PATH = joinpath(current_filepath, "\\res\\all_vertices.txt")
const OUTPUT_REL_PATH = "res/all_vertices.txt"

# ===== Legacy Support (backward compatibility) =====
"""
    get_inertiatodamping_functions(droop_parameters::Float64)::Tuple{Any, Vector}

Legacy function for backward compatibility.
Computes inertia-damping relationship for a given droop parameter.

This is a wrapper around the new workflow orchestrator.

# Arguments
- `droop_parameters::Float64`: Droop parameter value

# Returns
- `Tuple{Any, Vector}`: (plot, vertices)
"""
function get_inertiatodamping_functions(droop_parameters::Float64)::Tuple{Any, Vector}
    # Create controller config
    controller_config = converter_formming_configuations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    
    # Create computation config
    comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)
    
    # Execute workflow
    result = execute_workflow(droop_parameters, comp_cfg, controller_cfg)
    
    return result.plot, result.vertices
end
