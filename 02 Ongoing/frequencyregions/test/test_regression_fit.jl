@testset "quadratic regression fitting" begin
    damping = collect(2.0:1.0:6.0)
    expected = [1.5, -0.25, 0.75]
    inertia = reshape(expected[1] .+ expected[2] .* damping .+ expected[3] .* damping.^2, :, 1)

    params = calculate_fittingparameters(inertia, damping)

    @test length(params) == 3
    @test params ≈ expected atol=1e-6
end
