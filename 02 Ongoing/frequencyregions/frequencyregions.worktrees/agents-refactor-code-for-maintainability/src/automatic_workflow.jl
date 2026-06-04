include("environment_config.jl")

# --- Configuration and Bounds ---

const DEFAULT_CONVERTER_FLAG = Int64(0)
const MIN_DAMPING_BINDING = 2.5
const MAX_DAMPING_BINDING = 12.0

"""
    OperatingBounds
    
A struct to organize operating region bounds and control parameters.
"""
struct OperatingBounds
    min_inertia::Float64
    max_inertia::Vector{Float64}
    min_damping::Float64
    max_damping::Float64
    fitting_params::Vector{Float64}
    droop::Float64
end

# --- Core Workflow ---

"""
    get_inertiatodamping_functions(droop_value::Float64)

Main entry point for computing inertia-damping feasible region.
Returns plot and vertices of the feasible region polygon.
"""
function get_inertiatodamping_functions(droop_value::Float64)
    # Load controller configurations
    controller_config = converter_formming_configuations()
    converter_vsm_params = get(controller_config, "VSM", Dict())["control_parameters"]
    converter_droop_params = get(controller_config, "Droop", Dict())["control_parameters"]

    # Get baseline boundary conditions
    boundary_params = get_parmeters(DEFAULT_CONVERTER_FLAG)
    initial_inertia, factorial_coeff, time_const, _, rocof_threshold, _, power_dev = boundary_params

    # Calculate inertia-damping relationships
    inertia_bounds, extreme_inertia, nadir_vec, inertia_vec, selected_ids = 
        calculate_inertia_parameters(
            initial_inertia, factorial_coeff, time_const, droop_value, power_dev,
            DAMPING_RANGE, converter_vsm_params, converter_droop_params, DEFAULT_CONVERTER_FLAG
        )

    # Compute feasible limits
    min_inertia, max_inertia = estimate_inertia_limits(
        rocof_threshold, power_dev, DAMPING_RANGE, factorial_coeff, time_const, droop_value
    )

    # Fit quadratic relationship
    fitting_params = calculate_fittingparameters(extreme_inertia, DAMPING_RANGE)

    # Create operating bounds structure
    bounds = OperatingBounds(
        min_inertia, max_inertia,
        MIN_DAMPING_BINDING, MAX_DAMPING_BINDING,
        fitting_params, droop_value
    )

    # Generate visualization
    plot = visualize_inertia_bounds(
        DAMPING_RANGE, inertia_bounds, extreme_inertia,
        nadir_vec, inertia_vec, selected_ids, bounds
    )

    # Compute vertices of feasible region
    vertices = compute_feasible_region_vertices(DAMPING_RANGE, bounds)

    return plot, vertices
end

# --- Visualization Helpers ---

"""
    evaluate_polynomial(params::Vector, x)

Evaluate quadratic polynomial: params[1] + params[2]*x + params[3]*x²
"""
function evaluate_polynomial(params::Vector, x)
    return @. params[1] + params[2] * x + params[3] * x^2
end

"""
    visualize_inertia_bounds(damping, bounds_matrix, extreme_inertia,
                             nadir_vec, inertia_vec, selected_ids, bounds::OperatingBounds)

Create a comprehensive visualization of the inertia-damping operating region.
"""
function visualize_inertia_bounds(
        damping, bounds_matrix, extreme_inertia,
        nadir_vec, inertia_vec, selected_ids, bounds::OperatingBounds)

    # Evaluate fitted polynomial across damping range
    fitted_inertia = evaluate_polynomial(bounds.fitting_params, damping)

    # Create base plot with upper bound
    p = Plots.plot(
        damping, bounds_matrix[:, 1];
        framestyle=:box,
        ylims=(0, maximum(bounds_matrix[:, 1])),
        xlabel="damping / p.u.",
        ylabel="max inertia / p.u.",
        lw=3,
        label="upper_bound_1"
    )

    # Add lower bound
    Plots.plot!(p, damping, bounds_matrix[:, 2]; lw=3, label="lower_bound_2", color=:forestgreen)

    # Add fitted quadratic curve
    Plots.plot!(p, damping, fitted_inertia; lw=3, label="fitted_curve")

    # Add threshold lines
    Plots.hline!(p, [bounds.min_inertia]; lw=3, label="min_inertia")
    Plots.plot!(p, damping, bounds.max_inertia; lw=3, label="max_inertia")

    # Add damping binding constraints
    Plots.vline!(p, [bounds.max_damping]; lw=3, label="damping_max_binding")
    Plots.vline!(p, [bounds.min_damping]; lw=3, label="damping_min_binding")

    return p
end

# --- Vertex Calculation ---

"""
    find_damping_index(predicate, damping_range)

Find the first index in damping_range satisfying the predicate.
Throws error if not found.
"""
function find_damping_index(predicate, damping_range)
    index = findfirst(predicate, damping_range)
    index === nothing && error("No damping value found satisfying the condition.")
    return index
end

"""
    create_vertex(droop, damping, inertia)

Create an immutable vertex tuple (droop, damping, inertia).
"""
function create_vertex(droop, damping, inertia)
    return (droop, damping, inertia)
end

"""
    get_damping_indices(damping_range, min_damp, max_damp)

Compute the indices in damping_range corresponding to min/max damping values.
Returns: (max_damping_index, min_damping_index, max_damping_value, min_damping_value)
"""
function get_damping_indices(damping_range, min_damp, max_damp)
    max_idx = find_damping_index(x -> x > max_damp, damping_range) - 1
    min_idx = find_damping_index(x -> x > min_damp, damping_range) - 1
    
    return max_idx, min_idx, damping_range[max_idx], damping_range[min_idx]
end

"""
    compute_corner_vertices(droop, max_idx, min_idx, max_damp_val, min_damp_val,
                           min_inertia, max_inertia)

Compute the four corner vertices of the feasible region.
Returns: (vertex_max_damp_min_inertia, vertex_max_damp_max_inertia,
          vertex_min_damp_max_inertia, vertex_min_damp_min_inertia)
"""
function compute_corner_vertices(droop, max_idx, min_idx, max_damp_val, min_damp_val,
                                 min_inertia, max_inertia)
    return (
        create_vertex(droop, max_damp_val, min_inertia),
        create_vertex(droop, max_damp_val, max_inertia[max_idx]),
        create_vertex(droop, min_damp_val, max_inertia[min_idx]),
        create_vertex(droop, min_damp_val, min_inertia)
    )
end

"""
    is_min_inertia_binding(vertex_min_damp_min_inertia, vertex_min_damp_fitted)

Check if min_inertia constraint is active (binding).
"""
function is_min_inertia_binding(vertex_min_damp_min_inertia, vertex_min_damp_fitted)
    return vertex_min_damp_min_inertia > vertex_min_damp_fitted
end

"""
    is_max_inertia_binding(vertex_min_damp_max_inertia, vertex_min_damp_fitted)

Check if max_inertia constraint is active (binding).
"""
function is_max_inertia_binding(vertex_min_damp_max_inertia, vertex_min_damp_fitted)
    return vertex_min_damp_max_inertia > vertex_min_damp_fitted
end

"""
    compute_feasible_region_vertices(damping_range, bounds::OperatingBounds)

Compute vertices of the feasible inertia-damping region.
Returns vector of vertices ordered to form polygon boundary.
"""
function compute_feasible_region_vertices(damping_range, bounds::OperatingBounds)
    # Validate inputs
    if length(bounds.fitting_params) < 3
        error("fitting_params must have at least 3 elements")
    end
    isempty(damping_range) && error("damping_range cannot be empty")

    # Get damping indices and values
    max_idx, min_idx, max_damp_val, min_damp_val = 
        get_damping_indices(damping_range, bounds.min_damping, bounds.max_damping)

    # Get corner vertices
    v_max_min, v_max_max, v_min_max, v_min_min = 
        compute_corner_vertices(bounds.droop, max_idx, min_idx, max_damp_val, min_damp_val,
                               bounds.min_inertia, bounds.max_inertia)

    # Evaluate fitted curve at critical damping values
    fitted_at_min_damp = evaluate_polynomial(bounds.fitting_params, min_damp_val)
    v_min_fitted = create_vertex(bounds.droop, min_damp_val, fitted_at_min_damp)

    # Case 1: Min inertia constraint is binding
    if is_min_inertia_binding(v_min_min, v_min_fitted)
        return [v_max_max, v_max_min, v_min_min, v_min_max]
    end

    # Case 2: Min inertia active between min/max damping
    fitted_inertia = evaluate_polynomial(bounds.fitting_params, damping_range)
    min_inertia_idx = findfirst(x -> x < bounds.min_inertia, fitted_inertia)
    
    if min_inertia_idx === nothing
        min_inertia_idx = lastindex(fitted_inertia)
    else
        min_inertia_idx -= 1
    end

    v_min_inertia = create_vertex(bounds.droop, damping_range[min_inertia_idx], bounds.min_inertia)

    # Check if max inertia is binding
    if is_max_inertia_binding(v_min_max, v_min_fitted)
        return [v_max_max, v_max_min, v_min_inertia, v_min_fitted, v_min_max]
    end

    # Case 3: Both min and max inertia active
    inertia_diff = fitted_inertia - bounds.max_inertia
    max_inertia_idx = findfirst(x -> x < 0, inertia_diff)
    
    if max_inertia_idx === nothing
        max_inertia_idx = lastindex(fitted_inertia)
    else
        max_inertia_idx -= 1
    end

    v_fitted = create_vertex(bounds.droop, damping_range[max_inertia_idx],
                            fitted_inertia[max_inertia_idx])

    return [v_max_max, v_max_min, v_min_inertia, v_fitted]
end


# --- Data I/O Utilities ---

"""
    vertices_to_matrix(vertices::AbstractVector)

Convert a vector of vertex vectors to a single matrix.

# Arguments
- `vertices::AbstractVector`: Vector where each element is a vector of (droop, damping, inertia) tuples

# Returns
- `Matrix{Float64}`: Matrix with shape (n_points, 3)
- Empty matrix if input is empty
- `nothing` if input is malformed
"""
function vertices_to_matrix(vertices::AbstractVector)
    isempty(vertices) && return Matrix{Float64}(undef, 0, 3)

    first_element = first(vertices)
    !(eltype(first_element) <: Tuple) && 
        (@error "vertices must contain tuples"; return nothing)

    first_tuple_len = length(first(first_element))
    !all(all(length(v) == first_tuple_len for v in sv) for sv in vertices) &&
        (@error "Inconsistent tuple lengths"; return nothing)

    first_tuple_len != 3 && 
        (@error "Tuples must have length 3"; return nothing)

    # Allocate matrix
    total_points = sum(length(v) for v in vertices)
    matrix = Matrix{Float64}(undef, total_points, 3)

    # Fill matrix
    row = 1
    for sub_vertices in vertices
        for vertex in sub_vertices
            matrix[row, :] = collect(vertex)
            row += 1
        end
    end

    return matrix
end

"""
    write_vertices_to_file(all_vertices, base_path::String, rel_path::String)

Write vertex matrix to file (space-separated format).

# Arguments
- `all_vertices`: Matrix of shape (n, 3) with (droop, damping, inertia) rows
- `base_path`: Base directory path
- `rel_path`: Relative path from base_path
"""
function write_vertices_to_file(all_vertices, base_path::String, rel_path::String)
    output_path = joinpath(base_path, rel_path)
    mkpath(dirname(output_path))

    open(output_path, "w") do file
        for row in eachrow(all_vertices)
            length(row) >= 3 && write(file, "$(row[1]) $(row[2]) $(row[3])\n")
        end
    end
end
