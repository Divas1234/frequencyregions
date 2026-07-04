@testset "validation guards" begin
    empty_range = 1.0:0.5:0.0
    cfg = ComputationConfig(empty_range, 1.0, 2.0, 0)
    @test_throws ValidationError validate_computation_config(cfg)

    @test_throws ValidationError validate_inertia_limits(1.0, Float64[])
end
