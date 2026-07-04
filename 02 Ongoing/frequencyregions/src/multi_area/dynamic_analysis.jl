"""
    multi_area/dynamic_analysis.jl

Provides a physics-based 2-area frequency response model with primary control
and a nonlinear tie-line capacity limit. Solves the coupled differential equations
using Runge-Kutta 4th order (RK4) to find precise frequency nadir and ROCOF values.
"""

"""
    simulate_multiarea_frequency_response(...)

Simulates the dynamic frequency response of a 2-area power system connected via a tie-line.

# Arguments
- `H1`, `D1`, `R1`, `Tg1`, `Km1`: Parameters of Area 1 (Inertia, Damping, Droop, Gov constant, Turbine fraction)
- `DP1`: Disturbance in Area 1 (p.u. or % base)
- `H2`, `D2`, `R2`, `Tg2`, `Km2`: Parameters of Area 2
- `DP2`: Disturbance in Area 2 (typically 0.0 for healthy area)
- `T12`: Tie-line synchronizing coefficient
- `C12`: Tie-line capacity limit

# Returns
- `nadir1`, `nadir2`: Frequency nadir (maximum deviation in Hz) in Area 1 and Area 2
- `rocof1`, `rocof2`: Maximum Rate of Change of Frequency (Hz/s) in Area 1 and Area 2
"""
function simulate_multiarea_frequency_response(
    H1::Float64, D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
    H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
    T12::Float64, C12::Float64;
    t_max::Float64=10.0, dt::Float64=0.005
)
    # State variables:
    # df1  : Frequency deviation in Area 1 (Hz)
    # xg1  : Governor state in Area 1
    # df2  : Frequency deviation in Area 2 (Hz)
    # xg2  : Governor state in Area 2
    # P_tie: Power flow from Area 2 to Area 1 (%), constrained by -C12 and C12
    df1 = 0.0
    xg1 = 0.0
    df2 = 0.0
    xg2 = 0.0
    P_tie = 0.0

    n_steps = round(Int, t_max / dt)

    min_df1 = 0.0
    min_df2 = 0.0
    max_rocof1 = 0.0
    max_rocof2 = 0.0

    for step in 1:n_steps
        # Helper function to compute derivatives for RK4
        function get_derivatives(df1_val, xg1_val, df2_val, xg2_val, P_tie_val)
            Pm1 = - (Km1 / R1) * df1_val + (1.0 - Km1) * xg1_val
            Pm2 = - (Km2 / R2) * df2_val + (1.0 - Km2) * xg2_val

            ddf1 = (Pm1 - D1 * df1_val - DP1 + P_tie_val) / H1
            dxg1 = - (df1_val / (Tg1 * R1)) - (xg1_val / Tg1)

            ddf2 = (Pm2 - D2 * df2_val - DP2 - P_tie_val) / H2
            dxg2 = - (df2_val / (Tg2 * R2)) - (xg2_val / Tg2)

            # Tie-line dynamics: P_tie flows from 2 to 1, driven by df2 - df1
            # We scale the synchronizing coefficient by 2 * pi * f_base (f_base = 50 Hz)
            dP_tie = 2.0 * pi * 50.0 * T12 * (df2_val - df1_val)

            # Nonlinear clamping: if saturated, rate is zero in the direction of saturation
            if P_tie_val >= C12 && dP_tie > 0.0
                dP_tie = 0.0
            elseif P_tie_val <= -C12 && dP_tie < 0.0
                dP_tie = 0.0
            end

            return ddf1, dxg1, ddf2, dxg2, dP_tie
        end

        # Track current step's ROCOF
        Pm1_curr = - (Km1 / R1) * df1 + (1.0 - Km1) * xg1
        Pm2_curr = - (Km2 / R2) * df2 + (1.0 - Km2) * xg2

        rocof1_val = (Pm1_curr - D1 * df1 - DP1 + P_tie) / H1
        rocof2_val = (Pm2_curr - D2 * df2 - DP2 - P_tie) / H2

        max_rocof1 = max(max_rocof1, abs(rocof1_val))
        max_rocof2 = max(max_rocof2, abs(rocof2_val))

        # RK4 integrations
        k1_df1, k1_xg1, k1_df2, k1_xg2, k1_Ptie = get_derivatives(df1, xg1, df2, xg2, P_tie)

        k2_df1, k2_xg1, k2_df2, k2_xg2, k2_Ptie = get_derivatives(
            df1 + 0.5*dt*k1_df1, xg1 + 0.5*dt*k1_xg1,
            df2 + 0.5*dt*k1_df2, xg2 + 0.5*dt*k1_xg2,
            clamp(P_tie + 0.5*dt*k1_Ptie, -C12, C12)
        )

        k3_df1, k3_xg1, k3_df2, k3_xg2, k3_Ptie = get_derivatives(
            df1 + 0.5*dt*k2_df1, xg1 + 0.5*dt*k2_xg1,
            df2 + 0.5*dt*k2_df2, xg2 + 0.5*dt*k2_xg2,
            clamp(P_tie + 0.5*dt*k2_Ptie, -C12, C12)
        )

        k4_df1, k4_xg1, k4_df2, k4_xg2, k4_Ptie = get_derivatives(
            df1 + dt*k3_df1, xg1 + dt*k3_xg1,
            df2 + dt*k3_df2, xg2 + dt*k3_df2,
            clamp(P_tie + dt*k3_Ptie, -C12, C12)
        )

        df1 += (dt / 6.0) * (k1_df1 + 2.0*k2_df1 + 2.0*k3_df1 + k4_df1)
        xg1 += (dt / 6.0) * (k1_xg1 + 2.0*k2_xg1 + 2.0*k3_xg1 + k4_xg1)
        df2 += (dt / 6.0) * (k1_df2 + 2.0*k2_df2 + 2.0*k3_df2 + k4_df2)
        xg2 += (dt / 6.0) * (k1_xg2 + 2.0*k2_xg2 + 2.0*k3_xg2 + k4_xg2)
        P_tie = clamp(P_tie + (dt / 6.0) * (k1_Ptie + 2.0*k2_Ptie + 2.0*k3_Ptie + k4_Ptie), -C12, C12)

        min_df1 = min(min_df1, df1)
        min_df2 = min(min_df2, df2)
    end

    return abs(min_df1), abs(min_df2), max_rocof1, max_rocof2
end

"""
    find_critical_inertia_nadir(...) -> Float64

Performs a bisection search to find the minimum required inertia H1 that satisfies
the frequency nadir deviation threshold in Area 1.
"""
function find_critical_inertia_nadir(
    D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
    H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
    T12::Float64, C12::Float64, nadir_threshold1::Float64, nadir_threshold2::Float64;
    H_min_search::Float64=0.05, H_max_search::Float64=100.0, tol::Float64=1e-3
)
    # Check bounds
    n1_min_H, n2_min_H, _, _ = simulate_multiarea_frequency_response(
        H_max_search, D1, R1, Tg1, Km1, DP1,
        H2, D2, R2, Tg2, Km2, DP2,
        T12, C12
    )
    if n1_min_H > nadir_threshold1 || n2_min_H > nadir_threshold2
        # Even with max inertia, nadir is violated in either Area 1 or Area 2
        return H_max_search
    end

    n1_max_H, n2_max_H, _, _ = simulate_multiarea_frequency_response(
        H_min_search, D1, R1, Tg1, Km1, DP1,
        H2, D2, R2, Tg2, Km2, DP2,
        T12, C12
    )
    if n1_max_H <= nadir_threshold1 && n2_max_H <= nadir_threshold2
        # Even with min inertia, nadir is satisfied in both areas
        return H_min_search
    end

    low = H_min_search
    high = H_max_search
    mid = 0.5 * (low + high)

    while (high - low) > tol
        mid = 0.5 * (low + high)
        nadir1, nadir2, _, _ = simulate_multiarea_frequency_response(
            mid, D1, R1, Tg1, Km1, DP1,
            H2, D2, R2, Tg2, Km2, DP2,
            T12, C12
        )

        if nadir1 > nadir_threshold1 || nadir2 > nadir_threshold2
            # Need more inertia to satisfy both nadir constraints
            low = mid
        else
            high = mid
        end
    end

    return mid
end
