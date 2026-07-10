"""
    network_topology.jl

Defines built-in multi-area test systems and provides MATPOWER/PSS-E import.
Uses AreaParameters, TieLine, and MultiAreaSystem from config_structures.jl.
"""

"""
    build_ieee_2area_kundur() -> MultiAreaSystem

Builds the classic IEEE 2-area Kundur system (4 generators, 2 areas).

# Parameters (per-unit, base 100 MVA)

## Area 1 ("North")
- Equivalent inertia: H_eq ≈ 6.5 s  (2 generators × 6.5s each aggregated)
- Frequency regulation: R = 0.05  → droop = 1/0.05 = 20
- Factorial coefficient (turbine fraction): K_m = 0.35 (OCGT)
- Governor time constant: T_g = 0.25 s
- Largest credible contingency: 3.5 p.u. (nuclear unit trip)

## Area 2 ("South")  
- Equivalent inertia: H_eq ≈ 6.5 s  (2 generators × 6.5s each aggregated)
- Frequency regulation: R = 0.04  → droop = 1/0.04 = 25
- Factorial coefficient: K_m = 0.35
- Governor time constant: T_g = 0.25 s
- Largest contingency: 2.5 p.u.

## Tie line
- Synchronizing coefficient T_12 ≈ 4.0 p.u.  (2 parallel AC lines)
- Capacity: 400 MW ≈ 4.0 p.u.

# References
- P. Kundur, "Power System Stability and Control", Ch.12
- M. Klein, G. J. Rogers, P. Kundur, "A fundamental study of inter-area oscillations", IEEE Trans. Power Syst., 1991.
"""
function build_ieee_2area_kundur()
    area1 = AreaParameters(
        1,
        8.0,       # H_eq (matching baseline single-area)
        0.35,      # K_m (OCGT turbine fraction)
        0.25,      # T_g (governor time constant)
        1 / 0.03,  # droop = 1/R ≈ 33.33
        0.5,       # ROCOF threshold (Hz/s)
        0.5,       # NADIR threshold (Hz)
        3.5,       # largest contingency (p.u.)
    )

    area2 = AreaParameters(
        2,
        8.0,       # H_eq (same inertia as Area 1)
        0.35,      # K_m
        0.25,      # T_g
        1 / 0.03,  # droop = 1/R ≈ 33.33 (same, for fair comparison)
        0.5,
        0.5,
        2.0,       # smaller contingency (p.u.) — distinguishing factor
    )

    tie = TieLine(1, 2, 4.0, 1.0)  # T_sync=4.0 p.u., capacity=1.0 p.u.

    return MultiAreaSystem([area1, area2], [tie])
end


"""
    compute_tie_line_contribution(area_id::Int, system::MultiAreaSystem; factor::Float64=1.0) -> Float64

Calculates the worst-case tie-line power contribution for the given area.
For the decoupled approximation, this is the sum of all tie-line capacities
connected to the area, multiplied by a configurable decoupling factor.

# Arguments
- `area_id::Int`: Area identifier
- `system::MultiAreaSystem`: The multi-area system
- `factor::Float64`: Decoupling factor (0=none, 1=full worst-case, default 0.5 recommended)

# Returns
- The maximum possible tie-line power flow into/out of the area (p.u.)
"""
function compute_tie_line_contribution(area_id::Int, system::MultiAreaSystem; factor::Float64=0.5)
    total = 0.0
    for tl in system.tie_lines
        if tl.from_area == area_id || tl.to_area == area_id
            total += tl.capacity
        end
    end
    return total * factor
end


"""
    import_mypower_case(filename::String) -> MultiAreaSystem

Placeholder for MATPOWER (.m) case file import.
Reads bus, generator, and branch data to construct a MultiAreaSystem.

The implementation skeleton parses the MATPOWER case structure:
- mpc.area → groups generators into areas
- mpc.gen → generator inertia and controller parameters
- mpc.branch → inter-area tie lines

# Currently implemented: only returns a stub with the built-in 2-area system.
"""
function import_matpower_case(filename::String)
    println("[MATPOWER import] File: $filename")
    println("[MATPOWER import] Using built-in IEEE 2-area Kundur system as placeholder.")
    println("[MATPOWER import] Full .m case parser will be added with PowerSystems.jl integration.")
    return build_ieee_2area_kundur()
end


"""
    import_psse_raw(filename::String) -> MultiAreaSystem

Placeholder for PSS-E (.raw) raw data file import.

# Currently: stub that returns the built-in 2-area system.
"""
function import_psse_raw(filename::String)
    println("[PSS-E import] File: $filename")
    println("[PSS-E import] Full .raw parser requires PowerSystems.jl. Using default 2-area system.")
    return build_ieee_2area_kundur()
end
