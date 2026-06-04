include("src/environment_config.jl")

function run_multi_area_demo()
	println("--- Multi-Area Frequency Security Region Demo ---")

	# 1. Define Areas
	# Area 1: Large area with disturbance
	area1 = AreaParameters(
		"Area1",
		6.0,   # inertia
		5.0,   # damping
		1 / 0.03, # droop
		0.5,   # rocof threshold
		0.5,   # nadir threshold
		3.5,   # power deviation (disturbance occurs here)
		10.0,   # tieline stiffness T_12
	)

	# Area 2: Smaller area providing support
	area2 = AreaParameters(
		"Area2",
		2.0,   # inertia
		3.0,   # damping
		1 / 0.03, # droop
		0.5,   # rocof threshold
		0.5,   # nadir threshold
		0.0,   # no disturbance here
		10.0,   # tieline stiffness T_21
	)

	# Area 3: Additional support area
	area3 = AreaParameters(
		"Area3",
		3.0,   # inertia
		4.0,   # damping
		1 / 0.03, # droop
		0.5,   # rocof threshold
		0.5,   # nadir threshold
		0.0,   # no disturbance here
		10.0,   # tieline stiffness T_31
	)

	# 2. Configure Multi-Area System
	multi_config = MultiAreaConfig(
		[area1, area2, area3],
		Dict{Tuple{String, String}, Float64}(
			("Area1", "Area2") => 1.5, # Tie-line power limit: 1.5 MW/pu
			("Area1", "Area3") => 1.2, # Tie-line power limit: 1.2 MW/pu
			("Area2", "Area3") => 1.0, # Tie-line power limit: 1.0 MW/pu
		),
		"Area1",
		10.0, # Default tieline stiffness
	)

	# 3. Computation Configuration
	# Use standard damping range from constants
	comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)

	# 4. Controller Configuration
	controller_data = converter_formming_configuations()
	controller_cfg = ControllerConfig(
		controller_data["VSM"]["control_parameters"],
		controller_data["Droop"]["control_parameters"],
	)

	# 5. Execute Multi-Area Workflow
	println("Calculating multi-area security region...")
	result_multi = execute_multi_area_workflow(multi_config, comp_cfg, controller_cfg)

	# 5b. Execute Multi-Area Workflow per disturbance area
	println("Calculating per-area security regions...")
	results_by_area = Dict{String, ComputationResult}()
	for area in multi_config.areas
		area_config = MultiAreaConfig(
			multi_config.areas,
			multi_config.tie_line_limits,
			area.name,
			multi_config.default_tieline_stiffness,
		)
		results_by_area[area.name] = execute_multi_area_workflow(area_config, comp_cfg, controller_cfg)
	end

	# 6. Execute Single-Area Workflow (Aggregated) for comparison
	println("Calculating single-area (aggregated) baseline...")
	base_sys = create_system_parameters(comp_cfg.flag_converter)
	coi_sys = aggregate_to_system_parameters(multi_config, base_sys)
	result_single = execute_workflow(coi_sys, comp_cfg, controller_cfg)

	# 7. Generate Comparison Plot
	println("Generating comparison visualization...")
	comparison_plot = plot_multi_area_comparison(result_single, result_multi)

	# 7b. Generate Per-Area Region Plot
	println("Generating per-area visualization...")
	per_area_plot = plot_multi_area_ieee_regions(multi_config, comp_cfg, controller_cfg)

	# 8. Display Summary and Report
	println("Complete!")
	create_multi_area_report(result_multi, multi_config)
	for area in multi_config.areas
		area_config = MultiAreaConfig(
			multi_config.areas,
			multi_config.tie_line_limits,
			area.name,
			multi_config.default_tieline_stiffness,
		)
		println("\n--- Report for disturbance in $(area.name) ---")
		create_multi_area_report(results_by_area[area.name], area_config)
	end

	# 9. Save Plots
	output_dir = joinpath(pwd(), "fig")
	isdir(output_dir) || mkpath(output_dir)

	save_path_multi = joinpath(output_dir, "Multi_Area_Security_Region.png")
	save_path_comp = joinpath(output_dir, "Multi_vs_Single_Comparison.png")
	save_path_per_area = joinpath(output_dir, "Multi_Area_Per_Area_Regions.png")

	Plots.savefig(result_multi.plot, save_path_multi)
	Plots.savefig(comparison_plot, save_path_comp)
	Plots.savefig(per_area_plot, save_path_per_area)

	println("Main plot saved to: $save_path_multi")
	println("Comparison plot saved to: $save_path_comp")
	println("Per-area plot saved to: $save_path_per_area")

	return result_multi, comparison_plot, per_area_plot
end

# Run the demo
if abspath(PROGRAM_FILE) == @__FILE__
	run_multi_area_demo()
end
