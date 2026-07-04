"""
    decoupled_workflow.jl

Implements Option A: Decoupled Multi-Area Frequency Security Region Analysis.

# Core idea

Each area is treated as an independent single-area system. The inter-area
tie-line influence is approximated as an additional worst-case power disturbance
added to the area's internal contingency.

For area i:
    ΔP_eff(i) = ΔP_disturb(i) + Σ_{j tied to i} TieLine.capacity(j)

The single-area SFR model is then solved for each area independently.

# Conservative guarantee

Since tie-line capacity is an upper bound on actual power exchange during a
disturbance, the resulting feasible regions are **conservative** (inner
approximation). If (H, D, R) satisfy the constraints under the worst-case
ΔP_eff, they will also satisfy them under any milder tie-line condition.
"""

"""
    AreaResult

Container for a single area's computation results.

# Fields
- `area_id::Int`: Area identifier
- `result::ComputationResult`: Single-area workflow result
- `tie_contribution::Float64`: Worst-case tie-line power added (p.u.)
- `effective_disturbance::Float64`: ΔP_disturb + tie_contribution (p.u.)
"""
struct AreaResult
    area_id::Int
    result::ComputationResult
    tie_contribution::Float64
    effective_disturbance::Float64
end


"""
    execute_area_workflow(area::AreaParameters, tie_contribution::Float64,
                         config::ComputationConfig, controller_config::ControllerConfig) -> AreaResult

Runs the single-area frequency security analysis for one area, incorporating
the decoupled tie-line effect as an additional power disturbance.

# Arguments
- `area::AreaParameters`: Area parameters (inertia, droop, thresholds, etc.)
- `tie_contribution::Float64`: Sum of tie-line capacities connected to this area
- `config::ComputationConfig`: Shared computation configuration
- `controller_config::ControllerConfig`: VSM/Droop controller parameters

# Returns
- `AreaResult`: Area-level results (plot, vertices, bounds)
"""
function execute_area_workflow(area::AreaParameters, tie_contribution::Float64,
    config::ComputationConfig, controller_config::ControllerConfig)
    effective_disturbance = area.power_deviation + tie_contribution

    system_params = SystemParameters(
        area.initial_inertia,
        area.factorial_coefficient,
        area.time_constant,
        area.droop,
        area.rocof_threshold,
        area.nadir_threshold,
        effective_disturbance,
    )

    state = WorkflowState(controller_config, system_params, config)
    validate_all_configurations(state)

    try
        compute_inertia_bounds(state)
    catch e
        @warn "Area $(area.id): inertia bounds computation failed: $e"
        empty_verts = Vector{NamedTuple{(:droop, :damping, :inertia),Tuple{Float64,Float64,Float64}}}()
        empty_result = ComputationResult(area.droop, nothing, empty_verts,
            zeros(0, 2), zeros(3))
        return AreaResult(area.id, empty_result, tie_contribution, effective_disturbance)
    end

    min_inertia, max_inertia = estimate_inertia_limits(
        state.system_params.rocof_threshold,
        state.system_params.power_deviation,
        state.computation_config.damping_range,
        state.system_params.factorial_coefficient,
        state.system_params.time_constant,
        state.system_params.droop,
    )

    validate_inertia_limits(min_inertia, max_inertia)
    state.fitting_parameters = calculate_fittingparameters(
        state.extreme_inertia, state.computation_config.damping_range)

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
        state.fitting_parameters,
    )

    vertices = calculate_vertex(
        state.computation_config.damping_range,
        state.inertia_bounds,
        state.fitting_parameters,
        min_inertia,
        max_inertia_scalar,
        state.computation_config.min_damping,
        state.computation_config.max_damping,
        area.droop,
    )

    result = ComputationResult(area.droop, plot, vertices,
        state.inertia_bounds, state.fitting_parameters)

    return AreaResult(area.id, result, tie_contribution, effective_disturbance)
end


"""
    execute_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
                              controller_config::ControllerConfig) -> Vector{AreaResult}

Runs the decoupled multi-area frequency security analysis for all areas.

# Arguments
- `system::MultiAreaSystem`: Multi-area system definition
- `config::ComputationConfig`: Shared computation configuration
- `controller_config::ControllerConfig`: Shared VSM/Droop controller parameters

# Returns
- `Vector{AreaResult}`: One result per area
"""
function execute_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
    controller_config::ControllerConfig; factor::Float64=0.5)
    results = AreaResult[]

    for area in system.areas
        tie_contrib = compute_tie_line_contribution(area.id, system; factor=factor)
        println("--- Area $(area.id) ---")
        println("  Internal disturbance: $(area.power_deviation) p.u.")
        println("  Tie-line contribution: $(tie_contrib) p.u.")
        println("  Effective disturbance: $(area.power_deviation + tie_contrib) p.u.")

        area_result = execute_area_workflow(area, tie_contrib, config, controller_config)
        push!(results, area_result)

        println("  Vertices: $(length(area_result.result.vertices))")
        println("  Fitting params (c + b*D + a*D^2): $(area_result.result.fitting_parameters)")
    end

    return results
end


"""
    collect_all_vertices(results::Vector{AreaResult}) -> Matrix{Float64}

Collects all polygon vertices from all areas into a single matrix for export.
Each row: (area_id, droop, damping, inertia)

# Returns
- `Matrix{Float64}`: Vertices matrix with area_id as the first column
"""
function collect_all_vertices(results::Vector{AreaResult})
    all_verts = Matrix{Float64}[]
    for ar in results
        area_verts = [collect(v) for v in ar.result.vertices]
        if !isempty(area_verts)
            mat = hcat(fill(Float64(ar.area_id), length(area_verts)),
                reduce(hcat, area_verts)')
            push!(all_verts, mat)
        end
    end
    return isempty(all_verts) ? zeros(0, 4) : vcat(all_verts...)
end


"""
    print_multiarea_summary(results::Vector{AreaResult})

Prints a human-readable summary of multi-area computation results.
"""
function print_multiarea_summary(results::Vector{AreaResult})
    println("\n" * "="^60)
    println("  Multi-Area Frequency Security Region Summary")
    println("  Method: Decoupled Approximation (Option A)")
    println("="^60)

    for ar in results
        r = ar.result
        println("\n  Area $(ar.area_id):")
        println("    Droop: $(round(r.droop, digits=2))")
        println("    Effective ΔP: $(round(ar.effective_disturbance, digits=3)) p.u.")
        println("    Feasible vertices: $(length(r.vertices))")
        println("    Fit: H = $(round(r.fitting_parameters[1], digits=3)) + $(round(r.fitting_parameters[2], digits=3))·D + $(round(r.fitting_parameters[3], digits=3))·D²")
    end

    # Cross-area comparison
    if length(results) >= 2
        println("\n  Cross-area comparison:")
        v1 = length(results[1].result.vertices)
        v2 = length(results[2].result.vertices)
        println("    Area 1 has $(v1) vertices, Area 2 has $(v2) vertices")
        println("    ΔP_eff ratio: $(round(results[1].effective_disturbance / results[2].effective_disturbance, digits=3))")
    end
    println("="^60 * "\n")
end

"""
    execute_dynamic_area_workflow(area::AreaParameters, system::MultiAreaSystem,
                                 config::ComputationConfig, controller_config::ControllerConfig) -> AreaResult

Runs the multi-area frequency security analysis for one area using the physics-based
Dynamic Mutual Assistance Model.
"""
function execute_dynamic_area_workflow(
    area::AreaParameters,
    system::MultiAreaSystem,
    config::ComputationConfig,
    controller_config::ControllerConfig
)
    # Find the other areas in the system
    other_areas = [a for a in system.areas if a.id != area.id]
    if isempty(other_areas)
        error("Multi-area system must have at least two areas.")
    end
    area2 = other_areas[1] # For Kundur 2-area system

    # Retrieve tie-line parameters between area and area2
    T12 = 0.0
    C12 = 0.0
    for tl in system.tie_lines
        if (tl.from_area == area.id && tl.to_area == area2.id) ||
           (tl.from_area == area2.id && tl.to_area == area.id)
            T12 = tl.synchronizing_coeff
            C12 = tl.capacity
            break
        end
    end

    damping_range = config.damping_range

    # Calculate single-area zeta=1 bounds as stability reference bounds
    single_area_bounds = inertia_bindings(
        collect(damping_range),
        area.factorial_coefficient,
        area.time_constant,
        area.droop,
        controller_config.vsm_params,
        controller_config.droop_params,
        config.flag_converter
    )

    # Contingency settings: disturbance occurs in area, area2 is healthy
    DP1 = area.power_deviation
    DP2 = 0.0

    critical_nadir_inertias = Float64[]
    for D1 in damping_range
        # Baseline/nominal values for the other area (Area 2)
        H2 = area2.initial_inertia
        D2 = 4.0 # Nominal damping in Area 2
        R2 = area2.droop
        Tg2 = area2.time_constant
        Km2 = area2.factorial_coefficient

        H1_crit = find_critical_inertia_nadir(
            D1, area.droop, area.time_constant, area.factorial_coefficient, DP1,
            H2, D2, R2, Tg2, Km2, DP2,
            T12, C12, area.nadir_threshold, area2.nadir_threshold
        )
        push!(critical_nadir_inertias, H1_crit)
    end

    extreme_inertia = reshape(critical_nadir_inertias, :, 1)

    # Fit quadratic relation: H = c + b*D + a*D^2
    fitting_parameters = calculate_fittingparameters(extreme_inertia, damping_range)

    # Local ROCOF limit (tie-line doesn't help with initial ROCOF at t=0+)
    min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)

    # Calculate feasible region vertices
    max_inertia_scalar = maximum(single_area_bounds[:, 1])

    vertices = calculate_vertex(
        damping_range,
        single_area_bounds,
        fitting_parameters,
        min_inertia,
        max_inertia_scalar,
        config.min_damping,
        config.max_damping,
        area.droop
    )

    # Generate dynamic visualizer plot
    plot = sub_data_visualization(
        damping_range,
        min_inertia,
        max_inertia_scalar,
        single_area_bounds,
        extreme_inertia,
        zeros(length(damping_range), 25), # dummy
        zeros(length(damping_range), 25), # dummy
        zeros(length(damping_range)),      # dummy
        config.min_damping,
        config.max_damping,
        area.droop,
        fitting_parameters
    )

    result = ComputationResult(area.droop, plot, vertices, single_area_bounds, fitting_parameters)
    return AreaResult(area.id, result, 0.0, area.power_deviation)
end

"""
    execute_dynamic_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
                                      controller_config::ControllerConfig) -> Vector{AreaResult}

Runs the dynamic multi-area frequency security analysis for all areas.
"""
function execute_dynamic_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
    controller_config::ControllerConfig)
    results = AreaResult[]

    for area in system.areas
        println("--- Area $(area.id) (Dynamic Mutual Assistance) ---")
        println("  Internal disturbance: $(area.power_deviation) p.u.")

        area_result = execute_dynamic_area_workflow(area, system, config, controller_config)
        push!(results, area_result)

        println("  Vertices: $(length(area_result.result.vertices))")
        println("  Fitting params (c + b*D + a*D^2): $(area_result.result.fitting_parameters)")
    end

    return results
end

"""
    print_dynamic_multiarea_summary(results::Vector{AreaResult})

Prints a summary of the dynamic multi-area frequency security regions.
"""
function print_dynamic_multiarea_summary(results::Vector{AreaResult})
    println("\n" * "="^60)
    println("  Multi-Area Frequency Security Region Summary")
    println("  Method: Dynamic Mutual Assistance (Option B)")
    println("="^60)

    for ar in results
        r = ar.result
        println("\n  Area $(ar.area_id):")
        println("    Droop: $(round(r.droop, digits=2))")
        println("    Internal contingency ΔP: $(round(ar.effective_disturbance, digits=3)) p.u.")
        println("    Feasible vertices: $(length(r.vertices))")
        println("    Fit: H = $(round(r.fitting_parameters[1], digits=3)) + $(round(r.fitting_parameters[2], digits=3))·D + $(round(r.fitting_parameters[3], digits=3))·D²")
    end
    println("="^60 * "\n")
end
