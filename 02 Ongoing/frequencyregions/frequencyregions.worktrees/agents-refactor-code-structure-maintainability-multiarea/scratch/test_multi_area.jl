include("src/environment_config.jl")

# Sample Multi-Area Parameters
# Area 1: High inertia, low damping
# Area 2: Low inertia, high damping

function test_multi_area_aggregation()
    # Mock parameters
    h1, h2 = 4.0, 4.0
    d1, d2 = 5.0, 5.0
    r1, r2 = 33.0, 33.0
    dp = 3.5

    # COI Aggregation
    h_total = h1 + h2
    d_total = d1 + d2
    r_total = 1.0 / (1.0/r1 + 1.0/r2)

    println("Aggregated H: $h_total")
    println("Aggregated D: $d_total")
    println("Aggregated Droop: $r_total")

    # Use existing nadir calculation
    # We need other parameters like time_constant, etc.
    _, fact_C, time_C, _, rocof_T, nadir_T, _ = get_parmeters(0)
    
    # Calculate nadir using COI
    vsm_params = Dict("inertia" => 0.0, "damping" => 0.0)
    droop_params = Dict("droop" => 1/33.0)
    
    nadir = calculate_frequencynadir(h_total, fact_C, time_C, r_total, dp, d_total, vsm_params, droop_params, 0)
    println("COI Nadir: $nadir")
    
    # Check RoCoF in Area 1 (assuming disturbance in Area 1)
    rocof1 = dp / (2 * h1)
    println("Area 1 RoCoF: $rocof1 (Threshold: $rocof_T)")
end

test_multi_area_aggregation()
