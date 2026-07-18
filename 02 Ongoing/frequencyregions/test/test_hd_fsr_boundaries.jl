@testset "H-D multi-boundary FSR" begin
    system = build_fsr_case_system(1)
    result = calculate_hd_fsr_boundaries(system;
        damping_values = [2.5, 5.0, 7.5], h_max = 20.0, t_max = 6.0, dt = 0.02)

    @test length(result.damping) == 3
    @test length(result.nadir_h) == 3
    @test length(result.tie_h) == 3
    @test result.rocof_h > 0.0
    @test result.area >= 0.0
    @test_throws ArgumentError build_fsr_case_system(5)
end
