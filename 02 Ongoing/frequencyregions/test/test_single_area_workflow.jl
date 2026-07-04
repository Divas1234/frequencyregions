@testset "single-area workflow" begin
    controller_config = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)

    result = execute_workflow(36.0, comp_cfg, controller_cfg)

    @test result.droop == 36.0
    @test result.plot !== nothing
    @test !isempty(result.vertices)
    @test size(result.inertia_bounds, 2) == 2
    @test length(result.fitting_parameters) == 3
end
