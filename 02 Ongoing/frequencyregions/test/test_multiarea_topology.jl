@testset "multi-area topology" begin
    system = build_ieee_2area_kundur()

    @test length(system.areas) == 2
    @test length(system.tie_lines) == 1
    @test system.areas[1].id == 1
    @test system.areas[2].id == 2

    @test compute_tie_line_contribution(1, system; factor = 0.0) == 0.0
    @test compute_tie_line_contribution(1, system; factor = 0.5) == 0.5
    @test compute_tie_line_contribution(2, system; factor = 1.0) == 1.0

    # Test asymmetric resources system
    sys_asym = build_asymmetric_resources_system()
    @test length(sys_asym.areas) == 2
    @test sys_asym.areas[1].droop == 20.0
    @test sys_asym.areas[2].droop == 50.0
    @test sys_asym.areas[1].time_constant == 0.5
    @test sys_asym.areas[2].time_constant == 0.1

    # Test strong disturbed / weak healthy system
    sys_strong = build_strong_disturbed_weak_healthy_system()
    @test length(sys_strong.areas) == 2
    @test sys_strong.areas[1].droop == 50.0
    @test sys_strong.areas[2].droop == 20.0
    @test sys_strong.areas[1].time_constant == 0.1
    @test sys_strong.areas[2].time_constant == 0.5
end

