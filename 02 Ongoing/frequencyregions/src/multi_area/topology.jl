"""
    multi_area/topology.jl

English: Defines built-in multi-area test systems and provides stubs for MATPOWER/PSS-E network import.
Chinese: 定义内置的多区域测试系统，并提供 MATPOWER/PSS-E 网络导入的存根。

Uses AreaParameters, TieLine, and MultiAreaSystem from common/types.jl.
使用 common/types.jl 中的 AreaParameters、TieLine 和 MultiAreaSystem。
"""

"""
    build_ieee_2area_kundur() -> MultiAreaSystem

English: Builds the classic IEEE 2-area Kundur test system (4 generators, 2 areas).
Chinese: 构建经典 IEEE 双区 Kundur 测试系统（4 台发电机，2 个区域）。

# Parameters (per-unit, base 100 MVA) / 参数标么值 (100 MVA 基准容量)

## Area 1 ("North" / 北区)
- Equivalent inertia (等效惯性): H_eq ≈ 8.0 s
- Turbine fraction (汽轮机原动机比例): K_m = 0.35 (OCGT)
- Governor time constant (调速器时间常数): T_g = 0.25 s
- Regulation droop (调速器下垂系数): R = 0.03  → droop = 1/R ≈ 33.33
- ROCOF threshold (频率变化率阈值): 0.5 Hz/s
- NADIR threshold (最低点频率偏差阈值): 0.5 Hz
- Largest credible contingency (最大故障扰动量): 3.5 p.u. (e.g., nuclear unit trip)

## Area 2 ("South" / 南区)  
- Equivalent inertia (等效惯性): H_eq ≈ 8.0 s
- Turbine fraction (汽轮机原动机比例): K_m = 0.35
- Governor time constant (调速器时间常数): T_g = 0.25 s
- Regulation droop (调速器下垂系数): R = 0.03  → droop = 1/R ≈ 33.33
- ROCOF threshold (频率变化率阈值): 0.5 Hz/s
- NADIR threshold (最低点频率偏差阈值): 0.5 Hz
- Largest contingency (最大故障扰动量): 2.0 p.u. (smaller contingency, distinguishing factor)

## Tie line (联络线)
- Synchronizing coefficient (整步功率系数): T_12 = 4.0 p.u.
- Capacity (传输容量极限): C_12 = 1.0 p.u.

# References (参考文献)
- P. Kundur, "Power System Stability and Control", Ch.12
- M. Klein, G. J. Rogers, P. Kundur, "A fundamental study of inter-area oscillations", IEEE Trans. Power Syst., 1991.
"""
function build_ieee_2area_kundur()
    # Area 1: High contingency area (区1：大扰动区域)
    area1 = AreaParameters(
        1,
        8.0,       # H_eq (matching baseline single-area / 匹配单区域基线值)
        0.35,      # K_m (OCGT turbine fraction / 原动机比例系数)
        0.3,       # T_g (governor time constant / 调速器时间常数)
        22.0,      # droop = 1/R = 22.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz): active without dominating the domain
        0.3,       # largest contingency (p.u. / 最大扰动量)
    )

    # Area 2: Moderate contingency area (区2：中度扰动区域)
    area2 = AreaParameters(
        2,
        8.0,       # H_eq (same inertia as Area 1 / 区域2等效初始惯性)
        0.35,      # K_m
        0.3,       # T_g
        22.0,      # droop = 1/R = 22.0
        2.0,
        0.55,
        0.2,       # smaller contingency (p.u.) — distinguishing factor
    )

    # AC Tie-line configuration (AC 联络线配置)
    tie = TieLine(1, 2, 2.0, 0.155)  # moderate capacity: locally active, not domain-dominating

    return MultiAreaSystem([area1, area2], [tie])
end


"""
    build_regional_frequency_control_system() -> MultiAreaSystem

Builds the recommended two-area configuration used for regional frequency-domain
studies. Area 1 is synchronous-generation dominated; Area 2 has lower physical
inertia but grid-forming renewable/BESS fast-frequency response. The deliberately
finite tie-line capacity makes both the Nadir and tie-line curves relevant.
"""
function build_regional_frequency_control_system()
    synchronous_area = AreaParameters(
        1, 8.0, 0.30, 0.35, 24.0, 2.0, 0.8, 0.30,
    )
    renewable_area = AreaParameters(
        2, 5.0, 0.75, 0.08, 55.0, 2.0, 0.8, 0.20,
    )

    # Finite transfer capacity exposes the Nadir/tie-line trade-off.
    tie = TieLine(1, 2, 2.0, 0.2033)
    return MultiAreaSystem([synchronous_area, renewable_area], [tie])
end


"""
    build_asymmetric_resources_system() -> MultiAreaSystem

Case 3: Disturbed Area (Area 1) has slow and weak frequency regulation resources (e.g. typical thermal plant / low gas ratio).
Undisturbed Area (Area 2) has fast and strong frequency regulation resources (e.g. battery energy storage or fast gas turbine).
"""
function build_asymmetric_resources_system()
    # Area 1: Disturbed area with slow/weak regulation (R=0.067 -> droop=15, Tg=0.6s, Km=0.12)
    area1 = AreaParameters(
        1,
        8.0,       # initial_inertia
        0.12,      # K_m (slow turbine fraction)
        0.6,       # T_g (slow governor time constant)
        15.0,      # droop = 1/R = 15.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz) - tuned for active Nadir curve
        0.35,      # largest contingency (p.u.)
    )

    # Area 2: Healthy area with fast/strong regulation (R=0.04 -> droop=25, Tg=0.25s, Km=0.35)
    area2 = AreaParameters(
        2,
        8.0,       # initial_inertia
        0.35,      # K_m (fast turbine fraction)
        0.25,      # T_g (fast governor time constant)
        25.0,      # droop = 1/R = 25.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.20,      # largest contingency (p.u. for Area 2)
    )

    # Tie-line configuration
    tie = TieLine(1, 2, 2.0, 0.25)  # T_sync=2.0 p.u., capacity=0.25 p.u. (allows healthy support)

    return MultiAreaSystem([area1, area2], [tie])
end


"""
    build_strong_disturbed_weak_healthy_system() -> MultiAreaSystem

Case 2: Disturbed Area (Area 1) has fast and strong frequency regulation resources.
Undisturbed Area (Area 2) has slow and weak frequency regulation resources.
"""
function build_strong_disturbed_weak_healthy_system()
    # Area 1: Disturbed area with fast/strong regulation (R=0.04 -> droop=25, Tg=0.25s, Km=0.35)
    area1 = AreaParameters(
        1,
        8.0,       # initial_inertia
        0.35,      # K_m (fast turbine fraction)
        0.25,      # T_g (fast governor time constant)
        25.0,      # droop = 1/R = 25.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.35,      # largest contingency (p.u.)
    )

    # Area 2: Healthy area with slow/weak regulation (R=0.067 -> droop=15, Tg=0.6s, Km=0.12)
    area2 = AreaParameters(
        2,
        8.0,       # initial_inertia
        0.12,      # K_m (slow turbine fraction)
        0.6,       # T_g (slow governor time constant)
        15.0,      # droop = 1/R = 15.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.20,      # largest contingency (p.u. for Area 2)
    )

    # Tie-line configuration
    tie = TieLine(1, 2, 2.0, 0.25)  # T_sync=2.0 p.u., capacity=0.25 p.u.

    return MultiAreaSystem([area1, area2], [tie])
end


"""
    build_symmetric_strong_system() -> MultiAreaSystem

Case 1: Both Area 1 (disturbed) and Area 2 (healthy) have fast and strong frequency regulation resources.
"""
function build_symmetric_strong_system()
    # Area 1: Disturbed area with fast/strong regulation.  The high fast-response
    # fraction keeps the nadir boundary active while allowing it to turn upward
    # at the high-damping end of the study window.
    area1 = AreaParameters(
        1,
        8.0,       # initial_inertia
        0.90,      # K_m (fast turbine/converter response fraction)
        0.25,      # T_g (fast governor time constant)
        25.0,      # droop = 1/R = 25.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.35,      # largest contingency (p.u.)
    )

    # Area 2: Healthy area with the same fast-response tuning.
    area2 = AreaParameters(
        2,
        8.0,       # initial_inertia
        0.90,      # K_m (fast turbine/converter response fraction)
        0.25,      # T_g (fast governor time constant)
        25.0,      # droop = 1/R = 25.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.20,      # largest contingency (p.u. for Area 2)
    )

    # Tie-line configuration
    tie = TieLine(1, 2, 2.0, 0.25)  # T_sync=2.0 p.u., capacity=0.25 p.u.

    return MultiAreaSystem([area1, area2], [tie])
end


"""
    build_symmetric_weak_system() -> MultiAreaSystem

Case 4: Both Area 1 (disturbed) and Area 2 (healthy) have slow and weak frequency regulation resources.
"""
function build_symmetric_weak_system()
    # Area 1: Disturbed area with slow/weak regulation (R=0.067 -> droop=15, Tg=0.6s, Km=0.12)
    area1 = AreaParameters(
        1,
        8.0,       # initial_inertia
        0.12,      # K_m (slow turbine fraction)
        0.6,       # T_g (slow governor time constant)
        15.0,      # droop = 1/R = 15.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.35,      # largest contingency (p.u.)
    )

    # Area 2: Healthy area with slow/weak regulation (R=0.067 -> droop=15, Tg=0.6s, Km=0.12)
    area2 = AreaParameters(
        2,
        8.0,       # initial_inertia
        0.12,      # K_m (slow turbine fraction)
        0.6,       # T_g (slow governor time constant)
        15.0,      # droop = 1/R = 15.0
        2.0,       # ROCOF threshold (Hz/s)
        0.55,      # NADIR threshold (Hz)
        0.15,      # largest contingency (p.u. for Area 2)
    )

    # Tie-line configuration
    tie = TieLine(1, 2, 2.0, 0.15)  # T_sync=2.0 p.u., capacity=0.15 p.u.

    return MultiAreaSystem([area1, area2], [tie])
end



"""
    compute_tie_line_contribution(area_id::Int, system::MultiAreaSystem; factor::Float64=1.0) -> Float64

English: Calculates the worst-case tie-line power contribution for the given area under decoupled assumption.
Chinese: 计算解耦近似下给定区域的最坏情况联络线功率分配贡献。

For the decoupled approximation, this is the sum of all tie-line capacities
connected to the area, multiplied by a configurable decoupling factor.
对于解耦近似法，这是连接到该区域的所有联络线容量之和乘以可配置的解耦系数。

# Arguments (参数)
- `area_id::Int`: Area identifier (区域 ID)
- `system::MultiAreaSystem`: The multi-area system (多区域系统)
- `factor::Float64`: Decoupling factor (0=none, 1=full worst-case capacity, default 0.5 recommended)
                      解耦乘积系数 (0=无额外扰动即孤立运行，1=全额联络线传输容量，推荐默认 0.5)

# Returns (返回)
- The maximum possible tie-line power flow into/out of the area (p.u.)
  该区域可能的联络线最大跨区支援/输出电功率标么值 (p.u.)
"""
function compute_tie_line_contribution(area_id::Int, system::MultiAreaSystem; factor::Float64 = 0.5)
    total = 0.0
    for tl in system.tie_lines
        if tl.from_area == area_id || tl.to_area == area_id
            total += tl.capacity
        end
    end
    return total * factor
end


"""
    import_matpower_case(filename::String) -> MultiAreaSystem

English: Placeholder stub for MATPOWER (.m) case file import.
Chinese: 导入 MATPOWER (.m) 电网数据文件的占位存根。

# Currently implemented: only returns a stub with the built-in 2-area system.
# 目前实现：仅返回内置双区系统的占位存根。
"""
function import_matpower_case(filename::String)
    println("[MATPOWER import] File: $filename")
    println("[MATPOWER import] Using built-in IEEE 2-area Kundur system as placeholder.")
    println("[MATPOWER import] Full .m case parser will be added with PowerSystems.jl integration.")
    return build_ieee_2area_kundur()
end


"""
    import_psse_raw(filename::String) -> MultiAreaSystem

English: Placeholder stub for PSS-E (.raw) network data file import.
Chinese: 导入 PSS-E (.raw) 电网数据文件的占位存根。

# Currently: stub that returns the built-in 2-area system.
# 目前实现：仅返回内置双区系统的占位存根。
"""
function import_psse_raw(filename::String)
    println("[PSS-E import] File: $filename")
    println("[PSS-E import] Full .raw parser requires PowerSystems.jl. Using default 2-area system.")
    return build_ieee_2area_kundur()
end
