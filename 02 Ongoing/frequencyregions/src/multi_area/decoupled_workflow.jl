"""
    decoupled_workflow.jl

English: Implements Option A (Decoupled Multi-Area Frequency Security Region Analysis) 
and orchestrates workflows for Option B (Dynamic Mutual Assistance Model).
Chinese: 实现方案 A（解耦多区域频率安全区域分析）并协调方案 B（动态相互支援模型）的工作流。

# Core idea of Option A (方案 A 的核心思想)
Each area is treated as an independent single-area system. The inter-area
tie-line influence is approximated as an additional worst-case power disturbance
added to the area's internal contingency.
每个区域都被视为独立的单区域系统。区域间联络线的影响被近似为增加到该区域内部故障扰动之上的最坏情况联络线功率偏差。

For area i:
    ΔP_eff(i) = ΔP_disturb(i) + Σ_{j tied to i} TieLine.capacity(j) * factor

The single-area SFR model is then solved for each area independently.
然后在每个区域上独立求解单区域系统频率响应 (SFR) 模型。

# Conservative guarantee (保守性保证)
Since tie-line capacity is an upper bound on actual power exchange during a
disturbance, the resulting feasible regions are **conservative** (inner
approximation). If (H, D, R) satisfy the constraints under the worst-case
ΔP_eff, they will also satisfy them under any milder tie-line condition.
由于联络线传输极限是故障期间实际功率交换的上限，因此算出的可行域是**保守的**（内近似）。
如果 (H, D, R) 在最坏有功扰动功率 ΔP_eff 下满足约束，它们在任何较温和的联络线工况下也必然安全。
"""

"""
    AreaResult

English: Container for a single area's computation results.
Chinese: 单个控制区域计算结果的容器。

# Fields (字段)
- `area_id::Int`: Area identifier (区域 ID)
- `result::ComputationResult`: Single-area workflow result (单区域计算结果，包含顶点、拟合公式、画图等)
- `tie_contribution::Float64`: Worst-case tie-line power added (p.u.) (最坏情况下联络线功率分配贡献)
- `effective_disturbance::Float64`: ΔP_disturb + tie_contribution (p.u.) (等效总扰动量 ΔP_eff)
"""
struct AreaResult
    area_id::Int
    result::ComputationResult
    tie_contribution::Float64
    effective_disturbance::Float64
    nadir_fitting_parameters::Vector{Float64}
    tieline_fitting_parameters::Vector{Float64}
    nadir_inertia_limits::Vector{Float64}
    tieline_inertia_limits::Vector{Float64}
end

function AreaResult(area_id::Int, result::ComputationResult, tie_contribution::Float64, effective_disturbance::Float64)
    return AreaResult(area_id, result, tie_contribution, effective_disturbance,
        Float64[], Float64[], Float64[], Float64[])
end



"""
    execute_area_workflow(area::AreaParameters, tie_contribution::Float64,
                         config::ComputationConfig, controller_config::ControllerConfig) -> AreaResult

English: Runs the single-area frequency security analysis for one area, incorporating
the decoupled tie-line effect as an additional power disturbance.
Chinese: 运行单区域频率安全分析，将解耦联络线作用合并为额外的有功功率扰动。

# Arguments (参数)
- `area::AreaParameters`: Area parameters (inertia, droop, thresholds, etc.)
                          控制区域参数（惯性、下垂、安全阈值等）
- `tie_contribution::Float64`: Sum of tie-line capacities connected to this area (本区域连接的联络线容量之和)
- `config::ComputationConfig`: Shared computation configuration (计算设置配置)
- `controller_config::ControllerConfig`: VSM/Droop controller parameters (控制器参数)

# Returns (返回)
- `AreaResult`: Area-level results (plot, vertices, bounds)
                区域级别的最终计算结果 (包括绘图、顶点、边界)
"""
function execute_area_workflow(area::AreaParameters, tie_contribution::Float64,
    config::ComputationConfig, controller_config::ControllerConfig)
    effective_disturbance = area.power_deviation + tie_contribution

    # Instantiate single-area system parameters (实例化单区域系统参数)
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

    # 1. Compute stability/security boundaries (计算稳定与安全运行边界)
    try
        compute_inertia_bounds(state)
    catch e
        @warn "Area $(area.id): inertia bounds computation failed: $e"
        empty_verts = Vector{NamedTuple{(:droop, :damping, :inertia),Tuple{Float64,Float64,Float64}}}()
        empty_result = ComputationResult(area.droop, nothing, empty_verts,
            zeros(0, 2), zeros(3))
        return AreaResult(area.id, empty_result, tie_contribution, effective_disturbance)
    end

    # Estimate search ranges for inertia (评估惯性范围搜索上下限)
    min_inertia, max_inertia = estimate_inertia_limits(
        state.system_params.rocof_threshold,
        state.system_params.power_deviation,
        state.computation_config.damping_range,
        state.system_params.factorial_coefficient,
        state.system_params.time_constant,
        state.system_params.droop,
    )

    validate_inertia_limits(min_inertia, max_inertia)

    # 2. Fit boundary relations (二次拟合曲线公式)
    state.fitting_parameters = calculate_fittingparameters(
        state.extreme_inertia, state.computation_config.damping_range)

    max_inertia_scalar = isa(max_inertia, AbstractArray) ? maximum(vec(max_inertia)) : max_inertia

    # 3. Generate Plot (生成单区域 H-D 曲线图)
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

    # 4. Extract Polygon Vertices (提取可行域多边形顶点)
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
                               controller_config::ControllerConfig; factor::Float64=0.5) -> Vector{AreaResult}

English: Runs the decoupled multi-area frequency security analysis (Option A) for all areas.
Chinese: 运行所有区域的解耦多区域频率安全分析（方案 A）。

# Arguments (参数)
- `system::MultiAreaSystem`: Multi-area system definition (多区域互联系统定义)
- `config::ComputationConfig`: Shared computation configuration (计算设置配置)
- `controller_config::ControllerConfig`: Shared VSM/Droop controller parameters (控制器参数)
- `factor::Float64`: Decoupling margin scaling factor (解耦安全裕度比例因子)

# Returns (返回)
- `Vector{AreaResult}`: Vector of results for each area (每个区域的计算结果向量)
"""
function execute_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
    controller_config::ControllerConfig; factor::Float64=0.5)
    results = AreaResult[]

    for area in system.areas
        # Calculate pessimistic tie-line contribution (计算最坏有功流动方向贡献)
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

English: Collects all polygon vertices from all areas into a single matrix for file export.
Chinese: 将所有区域的可行域多边形顶点收集到单个矩阵中，以便导出到文件。

Each row: (area_id, droop, damping, inertia)
每行格式: (area_id, 下垂系数, 阻尼系数, 惯性常数)

# Returns (返回)
- `Matrix{Float64}`: Vertices matrix with area_id as the first column
                     以区域 ID 作为第一列的顶点参数矩阵
"""
function collect_all_vertices(results::Vector{AreaResult})
    all_verts = Matrix{Float64}[]
    for ar in results
        area_verts = [collect(v) for v in ar.result.vertices]
        if !isempty(area_verts)
            # Prepend area_id column to the vertices matrix (在前部拼接 area_id 列)
            mat = hcat(fill(Float64(ar.area_id), length(area_verts)),
                reduce(hcat, area_verts)')
            push!(all_verts, mat)
        end
    end
    return isempty(all_verts) ? zeros(0, 4) : vcat(all_verts...)
end


"""
    print_multiarea_summary(results::Vector{AreaResult})

English: Prints a human-readable summary of decoupled multi-area computation results.
Chinese: 打印解耦多区域计算结果的易读文本摘要。
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

    # Cross-area comparison (跨区域特性对比分析)
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

English: Runs the multi-area frequency security region analysis for one area using the physics-based
Dynamic Mutual Assistance Model (Option B) by simulating transient coupling.
Chinese: 基于物理的动态相互支援模型（方案 B），运行单个区域的动态频率安全区域分析（模拟瞬态耦合）。

This evaluates the real assistance the healthy area provides to the disturbed area through tie-line dynamics.
这评估了健全区域通过联络线动态为扰动发生区域提供的实际物理功率支援。
"""
function execute_dynamic_area_workflow(
    area::AreaParameters,
    system::MultiAreaSystem,
    config::ComputationConfig,
    controller_config::ControllerConfig
)
    # Find the other areas in the system (寻找系统中的其它协作区域)
    other_areas = [a for a in system.areas if a.id != area.id]
    if isempty(other_areas)
        error("Multi-area system must have at least two areas.")
    end
    area2 = other_areas[1] # For Kundur 2-area system (针对双区域 Kundur 系统取另一区)

    # Retrieve tie-line parameters between area and area2 (提取两区之间的联络线物理参数)
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

    # Dynamic boundary routines are typed for Float64. Normalize here so an
    # integer user sweep (for example `2:12`) remains a valid public input.
    damping_range = Float64.(collect(config.damping_range))

    # Calculate single-area zeta=1 bounds as stability reference bounds
    # 计算单区阻尼比为 1 时的惯性下限边界作为稳定运行基准参考线
    single_area_bounds = inertia_bindings(
        collect(damping_range),
        area.factorial_coefficient,
        area.time_constant,
        area.droop,
        controller_config.vsm_params,
        controller_config.droop_params,
        config.flag_converter
    )

    # Contingency settings: disturbance occurs in local area, area2 is healthy (ΔP2 = 0.0)
    # 故障发生在本区域，邻近协助区域处于稳定健康运行状态
    DP1 = area.power_deviation
    DP2 = 0.0

    # Bisection sweep over damping range to locate critical inertia
    # 对阻尼常数进行扫描，利用二分法在动态积分模拟中寻找临界安全惯性
    critical_nadir_inertias = Float64[]
    critical_tieline_inertias = Float64[]
	for (D_index, D1) in enumerate(damping_range)
        # Baseline/nominal values for the other area (Area 2)
        H2 = area2.initial_inertia
        D2 = 4.0 # Nominal damping in Area 2
		R2 = area2.droop
		Tg2 = area2.time_constant
		Km2 = area2.factorial_coefficient

		# Restrict the search to the local stability strip.  An arbitrarily tiny
		# inertia can create a numerical safe island that must not be stitched
		# into the H-D security polygon.
		stability_lower = max(single_area_bounds[D_index, 2], 0.05)
		stability_upper = single_area_bounds[D_index, 1]

		H1_nadir = find_critical_inertia_nadir(
			D1, area.droop, area.time_constant, area.factorial_coefficient, DP1,
			H2, D2, R2, Tg2, Km2, DP2,
			T12, C12, area.nadir_threshold, area2.nadir_threshold;
			H_min_search = stability_lower,
			H_max_search = stability_upper,
		)
        push!(critical_nadir_inertias, H1_nadir)

        # With no finite tie-line capacity there is no transfer-capacity
        # restriction; retain the local stability upper bound instead of using
        # a sentinel that would collapse the feasible region to zero width.
        H1_tieline = stability_upper
		if T12 > 0.0 && C12 > 0.0
			H1_tieline = find_critical_inertia_tieline(
				D1, area.droop, area.time_constant, area.factorial_coefficient, DP1,
				H2, D2, R2, Tg2, Km2, DP2,
				T12, C12;
				H_min_search = stability_lower,
				H_max_search = stability_upper,
			)
        end
        push!(critical_tieline_inertias, H1_tieline)
    end

    # Nadir is a minimum-inertia requirement. Tie-line capacity instead limits
    # the maximum permitted inertia because slower excursions can sustain a
    # larger inter-area transfer. Keep these constraints on their correct sides
    # of the feasible domain.
    extreme_inertia = reshape(critical_nadir_inertias, :, 1)
    single_area_bounds[:, 1] = min.(single_area_bounds[:, 1], critical_tieline_inertias)

    # Fit the lower Nadir boundary and the upper tie-line-capacity boundary.
    fitting_parameters = calculate_fittingparameters(extreme_inertia, damping_range)
    nadir_fitting_parameters = calculate_fittingparameters(reshape(critical_nadir_inertias, :, 1), damping_range)
    tieline_fitting_parameters = calculate_fittingparameters(reshape(critical_tieline_inertias, :, 1), damping_range)

    # Local ROCOF limit (tie-line doesn't help with initial ROCOF at t=0+ due to inertia response latency)
    # 局部 ROCOF 变化率限制（由于联络线功率滞后，在故障瞬间 t=0+ 联络线无法支援，ROCOF 纯由本地惯性决定）
    min_inertia = 0.5 * (area.power_deviation * PERCENTAGE_BASE) / (area.rocof_threshold * FREQUENCY_BASE)

    # Keep only the longest contiguous feasible damping interval. A sampled
    # boundary can contain isolated numerical safe points; stitching those
    # points to a later feasible interval would create a disconnected or
    # self-crossing polygon instead of one closed security region.
    fitted_nadir = fitting_parameters[1] .+ fitting_parameters[2] .* damping_range .+
                   fitting_parameters[3] .* damping_range .^ 2
    active_lower = max.(single_area_bounds[:, 2], min_inertia, fitted_nadir)
    feasible_mask = isfinite.(active_lower) .& isfinite.(single_area_bounds[:, 1]) .&
                    (damping_range .>= config.min_damping) .&
                    (damping_range .<= config.max_damping) .&
                    (active_lower .< single_area_bounds[:, 1] .- 1e-6)
    feasible_indices = largest_contiguous_true_run(feasible_mask)

    # Calculate feasible region vertices (计算动态可行域边界顶点)
    max_inertia_scalar = maximum(single_area_bounds[:, 1])
    vertices = if isempty(feasible_indices)
        Vector{NamedTuple{(:droop, :damping, :inertia),Tuple{Float64,Float64,Float64}}}()
    else
        selected_damping = damping_range[feasible_indices]
        selected_bounds = single_area_bounds[feasible_indices, :]
        calculate_vertex(
            selected_damping,
            selected_bounds,
            fitting_parameters,
            min_inertia,
            max_inertia_scalar,
            first(selected_damping),
            last(selected_damping),
            area.droop
        )
    end

    # Generate dynamic visualizer plot (生成动态相互支援模式下的安全区域可视化图形)
    plot = sub_data_visualization(
        damping_range,
        min_inertia,
        max_inertia_scalar,
        single_area_bounds,
        extreme_inertia,
        zeros(length(damping_range), 25), # dummy/占位
        zeros(length(damping_range), 25), # dummy/占位
        zeros(length(damping_range)),      # dummy/占位
        config.min_damping,
        config.max_damping,
        area.droop,
        fitting_parameters;
        feasible_indices=feasible_indices,
    )

    result = ComputationResult(area.droop, plot, vertices, single_area_bounds, fitting_parameters)
    return AreaResult(area.id, result, 0.0, area.power_deviation,
        nadir_fitting_parameters, tieline_fitting_parameters,
        critical_nadir_inertias, critical_tieline_inertias)
end

"""
    execute_dynamic_multiarea_workflow(system::MultiAreaSystem, config::ComputationConfig,
                                      controller_config::ControllerConfig) -> Vector{AreaResult}

English: Runs the dynamic multi-area frequency security analysis (Option B) for all areas.
Chinese: 运行所有区域的动态耦合互联频率安全分析（方案 B）。
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

English: Prints a summary of the dynamic multi-area frequency security regions (Option B).
Chinese: 打印动态耦合互联模式（方案 B）下多区域频率安全区域的计算摘要。
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
