@testset "multi-area topology" begin
    system = build_ieee_2area_kundur()

    @test length(system.areas) == 2
    @test length(system.tie_lines) == 1
    @test system.areas[1].id == 1
    @test system.areas[2].id == 2

    @test compute_tie_line_contribution(1, system; factor = 0.0) == 0.0
    @test compute_tie_line_contribution(1, system; factor = 0.5) == 0.075
    @test compute_tie_line_contribution(2, system; factor = 1.0) == 0.15

    # Test asymmetric resources system
    sys_asym = build_asymmetric_resources_system()
    @test length(sys_asym.areas) == 2
    @test sys_asym.areas[1].droop == 15.0
    @test sys_asym.areas[2].droop == 45.0
    @test sys_asym.areas[1].time_constant == 0.6
    @test sys_asym.areas[2].time_constant == 0.15

    # Test strong disturbed / weak healthy system
    sys_strong = build_strong_disturbed_weak_healthy_system()
    @test length(sys_strong.areas) == 2
    @test sys_strong.areas[1].droop == 45.0
    @test sys_strong.areas[2].droop == 15.0
    @test sys_strong.areas[1].time_constant == 0.15
    @test sys_strong.areas[2].time_constant == 0.6
end

