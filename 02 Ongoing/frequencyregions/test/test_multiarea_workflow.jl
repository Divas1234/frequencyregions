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

@testset "case 1 has a connected active nadir boundary" begin
    system = build_symmetric_strong_system()
    config = create_computation_config(2.5:1.0:15.0, 2.5, 15.0, 0)
    controller_config = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )

    @test all(area -> area.factorial_coefficient == 0.9, system.areas)
    @test all(area -> area.nadir_threshold == 0.55, system.areas)

    results = execute_dynamic_multiarea_workflow(system, config, controller_cfg)
    @test length(results) == 2

    for area_result in results
        bounds = area_result.result.inertia_bounds
        nadir = area_result.nadir_inertia_limits
        @test length(nadir) == length(config.damping_range)
        @test all(nadir .<= bounds[:, 1] .+ 1e-6)

        rocof_limit = 0.5 * (area_result.effective_disturbance * PERCENTAGE_BASE) /
                       (system.areas[area_result.area_id].rocof_threshold * FREQUENCY_BASE)
        active_lower = max.(bounds[:, 2], rocof_limit, area_result.result.fitting_parameters[1] .+
            area_result.result.fitting_parameters[2] .* collect(config.damping_range) .+
            area_result.result.fitting_parameters[3] .* collect(config.damping_range).^2)
        @test all(active_lower .< bounds[:, 1] .- 1e-6)
    end

    area1 = first(filter(result -> result.area_id == 1, results))
    active_nadir_points = sum(area1.nadir_inertia_limits .> area1.result.inertia_bounds[:, 2] .+ 0.1)
    @test active_nadir_points >= 3
    @test area1.nadir_inertia_limits[end] > minimum(area1.nadir_inertia_limits) + 0.05
    @test area1.nadir_inertia_limits[end] > area1.nadir_inertia_limits[end - 1]
    @test area1.result.fitting_parameters[3] > 0.0
end

@testset "case 1-4 produce closed connected dynamic regions" begin
    controller_config = converter_forming_configurations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    config = create_computation_config(2.5:1.0:15.0, 2.5, 15.0, 0)
    cases = [
        build_symmetric_strong_system(),
        build_strong_disturbed_weak_healthy_system(),
        build_asymmetric_resources_system(),
        build_symmetric_weak_system(),
    ]

    for system in cases
        results = execute_dynamic_multiarea_workflow(system, config, controller_cfg)
        @test length(results) == 2

        for area_result in results
            vertices = area_result.result.vertices
            @test iseven(length(vertices))
            half = div(length(vertices), 2)
            lower = vertices[1:half]
            upper = vertices[(half + 1):end]

            @test length(lower) >= 2
            @test [vertex[2] for vertex in lower] ==
                  reverse([vertex[2] for vertex in upper])
            @test lower[1][2] == upper[end][2]
            @test all(diff([vertex[2] for vertex in lower]) .> 0.0)
            @test all(lower[i][3] < upper[half - i + 1][3] - 1e-6 for i in eachindex(lower))
        end
    end
end
