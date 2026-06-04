"""
    mainfunction.jl

Refactored main execution script using the new structured workflow.

This script demonstrates the simplified usage of the new modular architecture.
It replaces the previous scattered validation logic with clean, type-safe abstractions.
"""

include("src/environment_config.jl")

println("""
╔════════════════════════════════════════════════════════════╗
║   Frequency Regions - Inertia-Damping Analysis           ║
║   Refactored Structured Workflow                          ║
╚════════════════════════════════════════════════════════════╝
""")

try
    # ===== Step 1: Create Configurations =====
    println("\n[1/5] Loading controller configurations...")
    controller_config = converter_formming_configuations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    
    # ===== Step 2: Create Computation Config =====
    println("[2/5] Setting up computation parameters...")
    comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)
    
    # ===== Step 3: Execute Workflow =====
    println("[3/5] Executing main workflow computation...")
    # Use droop value = 36.0 for this demonstration
    droop_value = 36.0
    result = execute_workflow(droop_value, comp_cfg, controller_cfg)
    
    # ===== Step 4: Display Results =====
    println("[4/5] Generating visualizations...")
    display(result.plot)
    
    # ===== Step 5: Save Results =====
    println("[5/5] Saving results...")
    output_dir = "fig"
    if !isdir(output_dir)
        mkdir(output_dir)
    end
    
    Plots.savefig(result.plot, joinpath(output_dir, "output_plot.png"))
    Plots.savefig(result.plot, joinpath(output_dir, "output_plot.pdf"))
    
    # Print summary
    println(get_workflow_summary(result))
    println("\n✓ Workflow completed successfully!")
    println("  - Plot saved to: fig/output_plot.png and fig/output_plot.pdf")
    println("  - Vertices: $(length(result.vertices)) points found")
    println("  - Droop: $(result.droop)")
    
catch e
    println("\n✗ Error during workflow execution:")
    if isa(e, ValidationError)
        println("  Validation Error: $(e.message)")
    else
        println("  $(typeof(e).name): $(e)")
        println("\nStacktrace:")
        Base.showerror(stdout, e)
    end
end

