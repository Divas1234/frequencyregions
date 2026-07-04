@testset "multi-area topology" begin
    system = build_ieee_2area_kundur()

    @test length(system.areas) == 2
    @test length(system.tie_lines) == 1
    @test system.areas[1].id == 1
    @test system.areas[2].id == 2

    @test compute_tie_line_contribution(1, system; factor = 0.0) == 0.0
    @test compute_tie_line_contribution(1, system; factor = 0.5) == 0.5
    @test compute_tie_line_contribution(2, system; factor = 1.0) == 1.0
end
