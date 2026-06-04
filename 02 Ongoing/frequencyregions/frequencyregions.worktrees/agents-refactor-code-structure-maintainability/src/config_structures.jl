"""
    config_structures.jl

Defines structured configuration objects for the frequency regions computation.
This replaces scattered Dict-based configurations with type-safe structs.
"""

"""
    ControllerConfig

Container for controller parameters (VSM and Droop).

# Fields
- `vsm_params::Dict`: VSM controller parameters (inertia, damping, time_constant)
- `droop_params::Dict`: Droop controller parameters (droop, time_constant)
"""
struct ControllerConfig
    vsm_params::Dict
    droop_params::Dict
    
    function ControllerConfig(vsm_params::Dict, droop_params::Dict)
        # Validation will happen in dedicated validation module
        new(vsm_params, droop_params)
    end
end

"""
    SystemParameters

Container for system boundary conditions and constraints.

# Fields
- `initial_inertia::Float64`: Initial system inertia
- `factorial_coefficient::Float64`: Factorial coefficient for calculations
- `time_constant::Float64`: System time constant
- `droop::Float64`: Droop value (can be overridden)
- `rocof_threshold::Float64`: Rate-of-Change-of-Frequency threshold
- `nadir_threshold::Float64`: Nadir (minimum frequency) threshold
- `power_deviation::Float64`: Power deviation value
"""
struct SystemParameters
    initial_inertia::Float64
    factorial_coefficient::Float64
    time_constant::Float64
    droop::Float64
    rocof_threshold::Float64
    nadir_threshold::Float64
    power_deviation::Float64
end

"""
    ComputationConfig

Container for computation settings and ranges.

# Fields
- `damping_range::AbstractRange`: Range of damping values to compute
- `min_damping::Float64`: Minimum damping value for output
- `max_damping::Float64`: Maximum damping value for output
- `flag_converter::Int64`: Converter type flag (0=traditional, 1=modern)
"""
struct ComputationConfig
    damping_range::AbstractRange
    min_damping::Float64
    max_damping::Float64
    flag_converter::Int64
    
    function ComputationConfig(damping_range::AbstractRange, min_damping::Float64, 
                              max_damping::Float64, flag_converter::Int64)
        if min_damping >= max_damping
            throw(ArgumentError("min_damping must be less than max_damping"))
        end
        new(damping_range, min_damping, max_damping, flag_converter)
    end
end

"""
    ComputationResult

Container for the results of a single droop parameter computation.

# Fields
- `droop::Float64`: Droop parameter used
- `plot::Any`: Visualization plot
- `vertices::Vector`: Feasible region vertices
- `inertia_bounds::Matrix`: Upper and lower inertia bounds
- `fitting_parameters::Vector`: Quadratic fit parameters (c, b, a)
"""
struct ComputationResult
    droop::Float64
    plot::Any
    vertices::Vector
    inertia_bounds::Matrix
    fitting_parameters::Vector
end

"""
    WorkflowState

Container for maintaining state during workflow execution.

# Fields
- `controller_config::ControllerConfig`: Controller parameters
- `system_params::SystemParameters`: System parameters
- `computation_config::ComputationConfig`: Computation settings
- `inertia_bounds::Any`: Computed inertia bounds
- `extreme_inertia::Any`: Extreme inertia values
- `nadir_vector::Any`: Nadir values
- `inertia_vector::Any`: Inertia values
- `selected_ids::Any`: Selected indices
- `fitting_parameters::Any`: Quadratic fit parameters
"""
mutable struct WorkflowState
    controller_config::ControllerConfig
    system_params::SystemParameters
    computation_config::ComputationConfig
    inertia_bounds::Any
    extreme_inertia::Any
    nadir_vector::Any
    inertia_vector::Any
    selected_ids::Any
    fitting_parameters::Any
    
    function WorkflowState(controller_config::ControllerConfig, 
                          system_params::SystemParameters,
                          computation_config::ComputationConfig)
        new(controller_config, system_params, computation_config,
            nothing, nothing, nothing, nothing, nothing, nothing)
    end
end

# Helper functions for config creation

"""
    create_system_parameters(flag_converter::Int64) -> SystemParameters

Create system parameters from boundary conditions.

# Arguments
- `flag_converter::Int64`: Converter type flag

# Returns
- `SystemParameters`: System parameters struct
"""
function create_system_parameters(flag_converter::Int64)::SystemParameters
    initial_inertia, factorial_coefficient, time_constant, droop, 
    rocof_threshold, nadir_threshold, power_deviation = get_parmeters(flag_converter)
    
    return SystemParameters(
        initial_inertia, factorial_coefficient, time_constant, droop,
        rocof_threshold, nadir_threshold, power_deviation
    )
end

"""
    create_computation_config(damping_range::AbstractRange, flag_converter::Int64) -> ComputationConfig

Create computation configuration with default values.

# Arguments
- `damping_range::AbstractRange`: Range of damping values
- `flag_converter::Int64`: Converter type flag

# Returns
- `ComputationConfig`: Computation configuration struct
"""
function create_computation_config(damping_range::AbstractRange, flag_converter::Int64)::ComputationConfig
    min_damping = minimum(damping_range)
    max_damping = maximum(damping_range)
    return ComputationConfig(damping_range, min_damping, max_damping, flag_converter)
end

"""
    create_computation_config(damping_range::AbstractRange, min_damping::Float64, 
                             max_damping::Float64, flag_converter::Int64) -> ComputationConfig

Create computation configuration with custom min/max damping.

# Arguments
- `damping_range::AbstractRange`: Range of damping values
- `min_damping::Float64`: Minimum damping for output
- `max_damping::Float64`: Maximum damping for output
- `flag_converter::Int64`: Converter type flag

# Returns
- `ComputationConfig`: Computation configuration struct
"""
function create_computation_config(damping_range::AbstractRange, min_damping::Float64, 
                                  max_damping::Float64, flag_converter::Int64)::ComputationConfig
    return ComputationConfig(damping_range, min_damping, max_damping, flag_converter)
end
