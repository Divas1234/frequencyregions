"""
    single_area/workflow.jl

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
    
    println("  -> Step 2.1: Initializing workflow state for droop = $droop...")
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
    
    println("  -> Step 2.2: Validating controller and system parameter constraints...")
    # Validate all configurations
    validate_all_configurations(state)
    
    println("  -> Step 2.3: Computing inertia stability boundaries by sweeping damping...")
    # Compute inertia bounds and parameters
    compute_inertia_bounds(state)
    
    println("  -> Step 2.4: Estimating dynamic inertia limits...")
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
    
    println("  -> Step 2.5: Performing quadratic regression fitting on inertia boundaries...")
    # Compute fitting parameters
    state.fitting_parameters = calculate_fittingparameters(state.extreme_inertia, 
                                                           state.computation_config.damping_range)
    
    println("  -> Step 2.6: Generating safety region visualization plot...")
    # Generate visualization
    plot = generate_visualization(state, min_inertia, max_inertia)
    
    println("  -> Step 2.7: Extracting feasible region boundary vertices...")
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
    
    println("  -> Step 2.8: Single-area workflow calculation complete.")
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
    
    # Generate publication-grade combined plot
    p_overlay = Plots.plot(;
        framestyle=:box,
        fontfamily=PLOT_FONT_FAMILY,
        tickdirection=:out,
        grid=true,
        gridalpha=0.12,
        gridcolor=:grey80,
        xlabel="Damping, D (p.u.)",
        ylabel="Inertia, H (s)",
        title="",
        titlefontsize=10,
        guidefontsize=9,
        tickfontsize=8,
        legendfontsize=8,
        fg_legend=:transparent,
        bg_legend=:transparent,
        left_margin=15Plots.px,
        bottom_margin=12Plots.px,
        top_margin=5Plots.px,
        right_margin=10Plots.px
    )

    damp_vals = collect(config.damping_range)
    n_results = length(results)
    color_palette = Plots.palette(:viridis, n_results)
    
    for (i, r) in enumerate(results)
        # Reconstruct the fit curve
        fit_curve = r.fitting_parameters[1] .+ r.fitting_parameters[2] .* damp_vals .+
                    r.fitting_parameters[3] .* damp_vals .^ 2
        
        # In single_area/workflow.jl, min_inertia is a scalar calculated inside execute_workflow.
        # To be safe, we can find the minimum inertia from the vertices, or recalculate it.
        # Since r.vertices is populated, the first half of r.vertices is the bottom boundary:
        # v = (droop, damp, H_bot)
        # Let's extract H_bot for the damping range.
        len = div(length(r.vertices), 2)
        if len > 0
            damp_sub = [r.vertices[k][2] for k in 1:len]
            h_bot_sub = [r.vertices[k][3] for k in 1:len]
            
            label = ""
            if i == 1
                label = "Min R = $(round(results[1].droop, digits=1))"
            elseif i == n_results
                label = "Max R = $(round(results[end].droop, digits=1))"
            end
            
            Plots.plot!(p_overlay, damp_sub, h_bot_sub;
                lw=1.5,
                color=color_palette[i],
                label=label
            )
        end
    end
    
    # Right panel: Intercept trend
    p_trend = Plots.plot(;
        framestyle=:box,
        fontfamily=PLOT_FONT_FAMILY,
        tickdirection=:out,
        grid=true,
        gridalpha=0.12,
        gridcolor=:grey80,
        xlabel="Governor Droop, R (p.u.)",
        ylabel="Intercept Coefficient, c",
        title="",
        titlefontsize=10,
        guidefontsize=9,
        tickfontsize=8,
        legend=false,
        left_margin=15Plots.px,
        bottom_margin=12Plots.px,
        top_margin=5Plots.px,
        right_margin=10Plots.px
    )
    
    droops = [r.droop for r in results]
    c_coefficients = [r.fitting_parameters[1] for r in results]
    
    Plots.plot!(p_trend, droops, c_coefficients;
        lw=1.5,
        color=COLOR_UPPER_BOUND,
        marker=:circle,
        markersize=3.5,
        markercolor=COLOR_ROCOF_LIMIT,
        markerstrokewidth=0
    )
    
    # Combined plot with panel labels
    p_overlay_labeled = Plots.plot(p_overlay, title="a", titlelocation=:left, titlefont=Plots.font(10, PLOT_FONT_FAMILY, :bold))
    p_trend_labeled = Plots.plot(p_trend, title="b", titlelocation=:left, titlefont=Plots.font(10, PLOT_FONT_FAMILY, :bold))
    
    combined_plot = Plots.plot(p_overlay_labeled, p_trend_labeled;
        layout=(1, 2),
        size=(700, 300)
    )
    
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

"""
    simulate_single_area_response(H, D, system_params, controller_config, flag_converter; t_max=6.0, dt=0.005)

Simulates the frequency response of a single-area power system using RK4.
Returns a tuple (time_steps, frequency_trajectory).
"""
function simulate_single_area_response(H, D, system_params, controller_config, flag_converter; t_max=6.0, dt=0.005)
    Tg = system_params.time_constant
    Kg = system_params.droop # governor gain (1/droop)
    DP = system_params.power_deviation
    F = system_params.factorial_coefficient
    
    # Adjust for converter VSM and droop
    H_tot = H
    D_tot = D
    if flag_converter == 1
        H_vsm = controller_config.vsm_params["inertia"]
        D_vsm = controller_config.vsm_params["damping"]
        R_vsm_droop = controller_config.droop_params["droop"]
        H_tot = H + H_vsm
        D_tot = D + D_vsm + 1.0 / R_vsm_droop
    end
    
    t_steps = 0:dt:t_max
    n_steps = length(t_steps)
    dw_hist = zeros(n_steps)
    
    # State variables: dw (frequency deviation in Hz), xg (governor state)
    dw = 0.0
    xg = 0.0
    
    for i in 1:n_steps
        dw_hist[i] = dw
        
        Pm = xg - F * dw
        ddw = (Pm - D_tot * dw - DP) / (2 * H_tot)
        dxg = (-xg - (Kg - F) * dw) / Tg
        
        # RK4
        k1_dw = ddw
        k1_xg = dxg
        
        dw2 = dw + 0.5 * dt * k1_dw
        xg2 = xg + 0.5 * dt * k1_xg
        ddw2 = ((xg2 - F * dw2) - D_tot * dw2 - DP) / (2 * H_tot)
        dxg2 = (-xg2 - (Kg - F) * dw2) / Tg
        k2_dw = ddw2
        k2_xg = dxg2
        
        dw3 = dw + 0.5 * dt * k2_dw
        xg3 = xg + 0.5 * dt * k2_xg
        ddw3 = ((xg3 - F * dw3) - D_tot * dw3 - DP) / (2 * H_tot)
        dxg3 = (-xg3 - (Kg - F) * dw3) / Tg
        k3_dw = ddw3
        k3_xg = dxg3
        
        dw4 = dw + dt * k3_dw
        xg4 = xg + dt * k3_xg
        ddw4 = ((xg4 - F * dw4) - D_tot * dw4 - DP) / (2 * H_tot)
        dxg4 = (-xg4 - (Kg - F) * dw4) / Tg
        k4_dw = ddw4
        k4_xg = dxg4
        
        dw += (dt / 6.0) * (k1_dw + 2.0 * k2_dw + 2.0 * k3_dw + k4_dw)
        xg += (dt / 6.0) * (k1_xg + 2.0 * k2_xg + 2.0 * k3_xg + k4_xg)
    end
    
    return collect(t_steps), 50.0 .+ dw_hist
end

"""
    plot_single_area_verification_trajectories(state::WorkflowState, min_inertia::Number, max_inertia_scalar::Number)

Plots a 2-panel verification figure showing both the safety region in the H-D plane (with selected points)
and their corresponding time-domain frequency trajectories.
"""
function plot_single_area_verification_trajectories(state::WorkflowState, min_inertia::Number, max_inertia_scalar::Number)
    damping = state.computation_config.damping_range
    extreme_inertia = state.extreme_inertia
    bounds_mat = collect(state.inertia_bounds)
    min_damping = state.computation_config.min_damping
    max_damping = state.computation_config.max_damping
    
    # 1. Select midpoint damping
    d_mid = (min_damping + max_damping) / 2
    idx = argmin(abs.(damping .- d_mid))
    D_val = damping[idx]
    
    # 2. Get boundary H
    H_boundary = max(bounds_mat[idx, 2], min_inertia, state.fitting_parameters[1] + state.fitting_parameters[2] * D_val + state.fitting_parameters[3] * D_val^2)
    
    # Define Points A, B, C
    H_secure = H_boundary + 3.0
    H_insecure = max(0.5, H_boundary - 2.0)
    
    # 3. Simulate
    t_A, f_A = simulate_single_area_response(H_secure, D_val, state.system_params, state.controller_config, state.computation_config.flag_converter)
    t_B, f_B = simulate_single_area_response(H_boundary, D_val, state.system_params, state.controller_config, state.computation_config.flag_converter)
    t_C, f_C = simulate_single_area_response(H_insecure, D_val, state.system_params, state.controller_config, state.computation_config.flag_converter)
    
    # 4. Plot left panel (H-D region with points A, B, C marked)
    p_region = sub_data_visualization(
        damping, min_inertia, max_inertia_scalar, state.inertia_bounds,
        extreme_inertia, state.nadir_vector, state.inertia_vector, state.selected_ids,
        min_damping, max_damping, state.system_params.droop, state.fitting_parameters
    )
    
    # Overlay points A, B, C on p_region
    Plots.scatter!(p_region, [D_val], [H_secure]; marker=:circle, markersize=5, color=COLOR_VERIFY_A, label="A (Secure)")
    Plots.scatter!(p_region, [D_val], [H_boundary]; marker=:rect, markersize=5, color=COLOR_VERIFY_B, label="B (Boundary)")
    Plots.scatter!(p_region, [D_val], [H_insecure]; marker=:utriangle, markersize=5, color=COLOR_VERIFY_C, label="C (Insecure)")
    
    # 5. Plot right panel (Time-domain trajectories)
    p_traj = Plots.plot(;
        framestyle=:box,
        fontfamily=PLOT_FONT_FAMILY,
        tickdirection=:out,
        grid=true,
        gridalpha=0.12,
        gridcolor=:grey80,
        xlabel="Time, t (s)",
        ylabel="Frequency, f (Hz)",
        title="",
        titlefontsize=10,
        guidefontsize=9,
        tickfontsize=8,
        legendfontsize=8,
        fg_legend=:transparent,
        bg_legend=:transparent,
        left_margin=15Plots.px,
        bottom_margin=12Plots.px,
        top_margin=5Plots.px,
        right_margin=10Plots.px,
        size=(350, 300)
    )
    
    Plots.plot!(p_traj, t_A, f_A; lw=1.5, color=COLOR_VERIFY_A, label="A (H=$(round(H_secure, digits=1)))")
    Plots.plot!(p_traj, t_B, f_B; lw=1.5, color=COLOR_VERIFY_B, label="B (H=$(round(H_boundary, digits=1)))")
    Plots.plot!(p_traj, t_C, f_C; lw=1.5, color=COLOR_VERIFY_C, label="C (H=$(round(H_insecure, digits=1)))")
    
    f_limit = 50.0 - (state.computation_config.flag_converter == 0 ? 0.25 : 0.1750)
    Plots.hline!(p_traj, [f_limit]; lw=1.2, color=COLOR_ROCOF_LIMIT, linestyle=:dash, label="Nadir limit")
    
    p_region_labeled = Plots.plot(p_region, title="a", titlelocation=:left, titlefont=Plots.font(10, PLOT_FONT_FAMILY, :bold))
    p_traj_labeled = Plots.plot(p_traj, title="b", titlelocation=:left, titlefont=Plots.font(10, PLOT_FONT_FAMILY, :bold))
    
    combined_plot = Plots.plot(p_region_labeled, p_traj_labeled;
        layout=(1, 2),
        size=(700, 300)
    )
    
    return combined_plot
end

