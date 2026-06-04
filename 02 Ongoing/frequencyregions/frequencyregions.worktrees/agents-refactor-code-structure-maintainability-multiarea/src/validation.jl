"""
    validation.jl

Provides validation functions for configuration and computation parameters.
Centralizes all validation logic for easier maintenance and consistency.
"""

"""
    ValidationError <: Exception

Custom exception for validation errors with clear messaging.
"""
struct ValidationError <: Exception
    message::String
end

Base.showerror(io::IO, e::ValidationError) = print(io, "ValidationError: $(e.message)")

"""
    validate_controller_config(config::ControllerConfig)

Validate controller configuration parameters.

# Arguments
- `config::ControllerConfig`: Controller configuration to validate

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_controller_config(config::ControllerConfig)::Bool
    # Validate VSM parameters
    required_vsm = ["inertia", "damping", "time_constant"]
    for param_name in required_vsm
        if !haskey(config.vsm_params, param_name)
            throw(ValidationError("Missing parameter '$param_name' in VSM configuration."))
        end
        param_value = config.vsm_params[param_name]
        if !isa(param_value, Number)
            throw(ValidationError("Parameter '$param_name' in VSM must be a number, got $(typeof(param_value))."))
        end
        if param_value <= 0
            throw(ValidationError("Parameter '$param_name' in VSM must be positive, got $param_value."))
        end
    end
    
    # Validate Droop parameters
    required_droop = ["droop", "time_constant"]
    for param_name in required_droop
        if !haskey(config.droop_params, param_name)
            throw(ValidationError("Missing parameter '$param_name' in Droop configuration."))
        end
        param_value = config.droop_params[param_name]
        if !isa(param_value, Number)
            throw(ValidationError("Parameter '$param_name' in Droop must be a number, got $(typeof(param_value))."))
        end
        # droop can be negative or positive, but time_constant must be positive
        if param_name == "time_constant" && param_value <= 0
            throw(ValidationError("Parameter '$param_name' in Droop must be positive, got $param_value."))
        end
    end
    
    return true
end

"""
    validate_system_parameters(params::SystemParameters)

Validate system parameters.

# Arguments
- `params::SystemParameters`: System parameters to validate

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_system_parameters(params::SystemParameters)::Bool
    checks = [
        ("initial_inertia", params.initial_inertia, true),
        ("factorial_coefficient", params.factorial_coefficient, true),
        ("time_constant", params.time_constant, true),
        ("rocof_threshold", params.rocof_threshold, true),
        ("nadir_threshold", params.nadir_threshold, true),
        ("power_deviation", params.power_deviation, true),
    ]
    
    for (name, value, must_be_positive) in checks
        if !isa(value, Number)
            throw(ValidationError("$name must be a number, got $(typeof(value))."))
        end
        if must_be_positive && value <= 0
            throw(ValidationError("$name must be positive, got $value."))
        end
    end
    
    # droop can be negative, just check it's a number
    if !isa(params.droop, Number)
        throw(ValidationError("droop must be a number, got $(typeof(params.droop))."))
    end
    
    return true
end

"""
    validate_computation_config(config::ComputationConfig)

Validate computation configuration.

# Arguments
- `config::ComputationConfig`: Computation configuration to validate

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_computation_config(config::ComputationConfig)::Bool
    if isempty(config.damping_range)
        throw(ValidationError("damping_range cannot be empty."))
    end
    
    damping_min = minimum(config.damping_range)
    damping_max = maximum(config.damping_range)
    
    if config.min_damping < damping_min
        throw(ValidationError("min_damping ($(config.min_damping)) cannot be less than damping_range minimum ($damping_min)."))
    end
    
    if config.max_damping > damping_max
        throw(ValidationError("max_damping ($(config.max_damping)) cannot be greater than damping_range maximum ($damping_max)."))
    end
    
    if config.min_damping >= config.max_damping
        throw(ValidationError("min_damping ($(config.min_damping)) must be less than max_damping ($(config.max_damping))."))
    end
    
    if config.flag_converter ∉ [0, 1]
        throw(ValidationError("flag_converter must be 0 (traditional) or 1 (modern), got $(config.flag_converter)."))
    end
    
    return true
end

"""
    validate_inertia_limits(min_inertia::Number, max_inertia)

Validate inertia limits from computation.

# Arguments
- `min_inertia::Number`: Minimum inertia value
- `max_inertia`: Vector or Matrix of maximum inertia values

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_inertia_limits(min_inertia::Number, max_inertia)::Bool
    if !isa(min_inertia, Number)
        throw(ValidationError("min_inertia must be a number, got $(typeof(min_inertia))."))
    end
    
    # Convert to array for consistent handling
    max_arr = vec(max_inertia)  # Convert to 1D array
    
    if isempty(max_arr) || !all(isa(x, Number) for x in max_arr)
        throw(ValidationError("max_inertia must be a non-empty array of numbers."))
    end
    
    if min_inertia >= maximum(max_arr)
        throw(ValidationError("min_inertia ($min_inertia) must be less than maximum max_inertia ($(maximum(max_arr)))."))
    end
    
    return true
end

"""
    validate_computation_results(inertia_bounds, extreme_inertia)

Validate computation results.

# Arguments
- `inertia_bounds`: Matrix of upper and lower inertia bounds
- `extreme_inertia`: Vector or Matrix of extreme inertia values

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_computation_results(inertia_bounds, extreme_inertia)::Bool
    # Convert to arrays for consistent handling
    bounds_arr = collect(inertia_bounds)
    
    if size(bounds_arr, 2) != 2
        throw(ValidationError("inertia_bounds must have 2 columns, got $(size(bounds_arr, 2))."))
    end
    
    # Handle both Vector and Matrix for extreme_inertia
    n_extreme = isa(extreme_inertia, Vector) ? length(extreme_inertia) : length(extreme_inertia)
    
    if n_extreme != size(bounds_arr, 1)
        throw(ValidationError("extreme_inertia length ($n_extreme) must match inertia_bounds rows ($(size(bounds_arr, 1)))."))
    end
    
    # Check upper > lower bounds
    for i in 1:size(bounds_arr, 1)
        if bounds_arr[i, 1] <= bounds_arr[i, 2]
            throw(ValidationError("Upper bound ($(bounds_arr[i, 1])) must be greater than lower bound ($(bounds_arr[i, 2])) at index $i."))
        end
    end
    
    return true
end

"""
    validate_droop_parameters(droop_params::AbstractVector)

Validate droop parameter vector.

# Arguments
- `droop_params::AbstractVector`: Vector of droop parameters

# Throws
- `ValidationError`: If validation fails

# Returns
- `true`: If validation passes
"""
function validate_droop_parameters(droop_params::AbstractVector)::Bool
    if isempty(droop_params)
        throw(ValidationError("droop_params cannot be empty."))
    end
    
    if !all(isa(x, Number) for x in droop_params)
        throw(ValidationError("All droop_params must be numbers."))
    end
    
    return true
end

"""
    safe_validate(validator_func::Function, arg::Any)

Wrapper for safe validation with try-catch.

# Arguments
- `validator_func::Function`: Validation function to call
- `arg::Any`: Single argument to pass to validator function

# Returns
- `Tuple{Bool, Union{String, Nothing}}`: (is_valid, error_message)
"""
function safe_validate(validator_func::Function, arg::Any)::Tuple{Bool, Union{String, Nothing}}
    try
        validator_func(arg)
        return (true, nothing)
    catch e
        if isa(e, ValidationError)
            return (false, e.message)
        else
            return (false, string(e))
        end
    end
end

"""
    safe_validate(validator_func::Function, arg1::Any, arg2::Any)

Wrapper for safe validation with two arguments.

# Arguments
- `validator_func::Function`: Validation function to call
- `arg1::Any`: First argument to pass to validator function
- `arg2::Any`: Second argument to pass to validator function

# Returns
- `Tuple{Bool, Union{String, Nothing}}`: (is_valid, error_message)
"""
function safe_validate(validator_func::Function, arg1::Any, arg2::Any)::Tuple{Bool, Union{String, Nothing}}
    try
        validator_func(arg1, arg2)
        return (true, nothing)
    catch e
        if isa(e, ValidationError)
            return (false, e.message)
        else
            return (false, string(e))
        end
    end
end

"""
    log_validation(is_valid::Bool, component_name::String, error_msg::Union{String, Nothing}=nothing)

Log validation result to console.

# Arguments
- `is_valid::Bool`: Whether validation passed
- `component_name::String`: Name of component being validated
- `error_msg::Union{String, Nothing}`: Error message if validation failed
"""
function log_validation(is_valid::Bool, component_name::String, error_msg::Union{String, Nothing}=nothing)
    if is_valid
        println("✓ $component_name validated successfully.")
    else
        println("✗ $component_name validation failed: $error_msg")
    end
end
