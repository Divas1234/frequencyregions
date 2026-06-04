"""
    workflow_orchestrator.jl

Orchestrates the entire computation workflow for inertia-damping analysis.
Provides high-level, easy-to-use functions that manage the complex interactions
between different computation modules.
"""

"""
    execute_workflow(droop::Float64, config::ComputationConfig, controller_config::ControllerConfig)::ComputationResult

Execute the complete workflow for a single droop parameter.

This is the main entry point for computation. It orchestrates all steps:
1. Load and validate configurations
2. Create system parameters
3. Compute inertia bounds
4. Estimate inertia limits
5. Calculate fitting parameters
6. Generate visualizations
7. Calculate vertices

# Arguments
- `droop::Float64`: Droop parameter value
- `config::ComputationConfig`: Computation configuration
- `controller_config::ControllerConfig`: Controller configuration

# Returns
- `ComputationResult`: Complete result containing plot, vertices, bounds, and parameters

# Example
```julia
controller_cfg = ControllerConfig(vsm_params, droop_params)
comp_cfg = create_computation_config(DAMPING_RANGE, 2.5, 12.0, 0)
result = execute_workflow(33.0, comp_cfg, controller_cfg)
```
"""
function execute_workflow(droop::Float64, config::ComputationConfig, 
                         controller_config::ControllerConfig)::ComputationResult
    
    # Initialize state
    system_params = create_system_parameters(config.flag_converter)
    state = WorkflowState(controller_config, system_params, config)
    
    # Update droop value
    state.system_params = SystemParameters(
        system_params.initial_inertia,
        system_params.factorial_coefficient,
        system_params.time_constant,
        droop,  # Override with provided droop
        system_params.rocof_threshold,
        system_params.nadir_threshold,
        system_params.power_deviation
    )
    
    # Validate all configurations
    validate_all_configurations(state)
    
    # Compute inertia bounds and parameters
    compute_inertia_bounds(state)
    
    # Estimate inertia limits
    min_inertia, max_inertia = estimate_inertia_limits(
        state.system_params.rocof_threshold,
        state.system_params.power_deviation,
        state.computation_config.damping_range,
        state.system_params.factorial_coefficient,
        state.system_params.time_constant,
        state.system_params.droop
    )
    
    validate_inertia_limits(min_inertia, max_inertia)
    
    # Compute fitting parameters
    state.fitting_parameters = calculate_fittingparameters(state.extreme_inertia, 
                                                           state.computation_config.damping_range)
    
    # Generate visualization
    plot = generate_visualization(state, min_inertia, max_inertia)
    
    # Calculate vertices (feasible region corners)
    vertices = calculate_vertex(
        state.computation_config.damping_range,
        state.inertia_bounds,
        state.fitting_parameters,
        min_inertia,
        maximum(max_inertia),
        state.computation_config.min_damping,
        state.computation_config.max_damping,
        droop
    )
    
    # Return structured result
    return ComputationResult(
        droop,
        plot,
        vertices,
        state.inertia_bounds,
        state.fitting_parameters
    )
end

"""
    execute_batch_workflow(droop_parameters::AbstractVector, config::ComputationConfig,
                          controller_config::ControllerConfig)::Tuple{Any, Matrix}

Execute workflow for multiple droop parameters.

# Arguments
- `droop_parameters::AbstractVector`: Vector of droop values to compute
- `config::ComputationConfig`: Computation configuration
- `controller_config::ControllerConfig`: Controller configuration

# Returns
- `Tuple{Any, Matrix}`: (combined_plot, all_vertices_matrix)

# Throws
- `ValidationError`: If configuration is invalid
"""
function execute_batch_workflow(droop_parameters::AbstractVector, config::ComputationConfig,
                               controller_config::ControllerConfig)::Tuple{Any, Matrix}
    
    if isempty(droop_parameters)
        throw(ValidationError("droop_parameters cannot be empty."))
    end
    
    results = ComputationResult[]
    
    for droop_value in droop_parameters
        try
            result = execute_workflow(droop_value, config, controller_config)
            push!(results, result)
            println("✓ Completed droop=$droop_value")
        catch e
            @warn "Failed to compute droop=$droop_value: $(e)"
            continue
        end
    end
    
    if isempty(results)
        throw(ValidationError("No successful computations. Check droop_parameters and configuration."))
    end
    
    # Combine plots
    plots = [r.plot for r in results]
    labels = [round_droop_label(r.droop) for r in results]
    combined_plot = Plots.plot(plots...; legend=false, size=(1000, 1000), 
                              xlabel="Damping", ylabel="Inertia", 
                              label=permutedims(labels))
    
    # Combine vertices
    all_vertices = [r.vertices for r in results]
    vertices_matrix = vertices_to_matrix(all_vertices)
    
    if vertices_matrix === nothing
        throw(ValidationError("Failed to convert vertices to matrix. Check vertices format."))
    end
    
    return combined_plot, vertices_matrix
end

"""
    validate_all_configurations(state::WorkflowState)

Validate all components of the workflow state.

# Throws
- `ValidationError`: If any validation fails
"""
function validate_all_configurations(state::WorkflowState)
    
    # Validate controller config
    is_valid, error_msg = safe_validate(validate_controller_config, state.controller_config)
    if !is_valid
        throw(ValidationError("Controller configuration: $error_msg"))
    end
    log_validation(is_valid, "Controller configuration")
    
    # Validate system parameters
    is_valid, error_msg = safe_validate(validate_system_parameters, state.system_params)
    if !is_valid
        throw(ValidationError("System parameters: $error_msg"))
    end
    log_validation(is_valid, "System parameters")
    
    # Validate computation config
    is_valid, error_msg = safe_validate(validate_computation_config, state.computation_config)
    if !is_valid
        throw(ValidationError("Computation configuration: $error_msg"))
    end
    log_validation(is_valid, "Computation configuration")
end

"""
    compute_inertia_bounds(state::WorkflowState)

Compute inertia bounds and related parameters, storing results in state.

# Arguments
- `state::WorkflowState`: Workflow state to update (modified in place)
"""
function compute_inertia_bounds(state::WorkflowState)
    
    inertia_bounds, extreme_inertia, nadir_vector, inertia_vector, selected_ids = 
        calculate_inertia_parameters(
            state.system_params.initial_inertia,
            state.system_params.factorial_coefficient,
            state.system_params.time_constant,
            state.system_params.droop,
            state.system_params.power_deviation,
            state.computation_config.damping_range,
            state.controller_config.vsm_params,
            state.controller_config.droop_params,
            state.computation_config.flag_converter
        )
    
    # Validate results
    is_valid, error_msg = safe_validate(validate_computation_results, inertia_bounds, extreme_inertia)
    if !is_valid
        throw(ValidationError("Computation results validation: $error_msg"))
    end
    log_validation(is_valid, "Inertia bounds computation")
    
    # Store in state
    state.inertia_bounds = inertia_bounds
    state.extreme_inertia = extreme_inertia
    state.nadir_vector = nadir_vector
    state.inertia_vector = inertia_vector
    state.selected_ids = selected_ids
end

"""
    generate_visualization(state::WorkflowState, min_inertia::Number, max_inertia)::Any

Generate visualization plot from computed data.

# Arguments
- `state::WorkflowState`: Workflow state with computed data
- `min_inertia::Number`: Minimum inertia limit
- `max_inertia`: Maximum inertia limits

# Returns
- `Any`: Plots.jl plot object
"""
function generate_visualization(state::WorkflowState, min_inertia::Number, max_inertia)::Any
    
    # Ensure fitting parameters are computed
    if isnothing(state.fitting_parameters)
        throw(ValidationError("Fitting parameters must be computed before visualization. Call compute_inertia_bounds first."))
    end
    
    # Convert max_inertia to scalar if needed
    max_inertia_scalar = isa(max_inertia, AbstractArray) ? maximum(vec(max_inertia)) : max_inertia
    
    plot = sub_data_visualization(
        state.computation_config.damping_range,
        min_inertia,
        max_inertia_scalar,
        state.inertia_bounds,
        state.extreme_inertia,
        state.nadir_vector,
        state.inertia_vector,
        state.selected_ids,
        state.computation_config.min_damping,
        state.computation_config.max_damping,
        state.system_params.droop,
        state.fitting_parameters
    )
    
    return plot
end

"""
    round_droop_label(droop::Float64; digits::Int=3)::String

Create a readable label for droop parameter.

# Arguments
- `droop::Float64`: Droop value
- `digits::Int`: Number of digits for rounding

# Returns
- `String`: Formatted label like "Droop 1/0.030"
"""
function round_droop_label(droop::Float64; digits::Int=3)::String
    if droop != 0
        reciprocal = round(1 / droop, digits=digits)
        return "Droop 1/$(reciprocal)"
    else
        return "Droop ∞"
    end
end

"""
    create_workflow_state_from_config(controller_config::ControllerConfig,
                                     computation_config::ComputationConfig)::WorkflowState

Create and initialize a workflow state from configurations.

# Arguments
- `controller_config::ControllerConfig`: Controller configuration
- `computation_config::ComputationConfig`: Computation configuration

# Returns
- `WorkflowState`: Initialized workflow state
"""
function create_workflow_state_from_config(controller_config::ControllerConfig,
                                          computation_config::ComputationConfig)::WorkflowState
    
    system_params = create_system_parameters(computation_config.flag_converter)
    return WorkflowState(controller_config, system_params, computation_config)
end

"""
    get_workflow_summary(result::ComputationResult)::String

Generate a human-readable summary of computation results.

# Arguments
- `result::ComputationResult`: Computation result

# Returns
- `String`: Summary string
"""
function get_workflow_summary(result::ComputationResult)::String
    summary = """
    ===== Workflow Results Summary =====
    Droop: $(result.droop)
    Vertices found: $(length(result.vertices))
    Fitting parameters (c + b*x + a*x²): $(result.fitting_parameters)
    Inertia bounds shape: $(size(result.inertia_bounds))
    ====================================
    """
    return summary
end
