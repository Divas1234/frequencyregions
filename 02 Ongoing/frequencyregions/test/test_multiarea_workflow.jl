@testset "multi-area workflow" begin
    controller_config = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    comp_cfg = create_computation_config(DAMPING_RANGE, 2.5, 12.0, 0)
    system = build_ieee_2area_kundur()

    results = execute_multiarea_workflow(system, comp_cfg, controller_cfg; factor = 0.1)

    @test length(results) == 2
    @test all(r -> r.area_id in (1, 2), results)
    @test all(r -> length(r.result.fitting_parameters) == 3, results)
    @test all(r -> size(r.result.inertia_bounds, 2) == 2, results)

    summary = run_multiarea_analysis(system = system, output_path = joinpath(mktempdir(), "all_vertices_multiarea.txt"), decoupling_factor = 0.1)
    @test haskey(summary, :comparison_plot)
    @test haskey(summary, :overlay_plot)
    @test haskey(summary, :summary_plot)
    @test haskey(summary, :results)
    @test haskey(summary, :all_vertices)
    @test length(summary.results) == 2

    summary_path = joinpath(mktempdir(), "multiarea_summary.pdf")
    Plots.savefig(summary.summary_plot, summary_path)
    @test isfile(summary_path)
end
