"""
    enhanced_mainfunction.jl

Refactored batch processing script using the new structured workflow.

This script demonstrates how to process multiple droop parameters efficiently
using the new modular architecture.
"""

include("src/environment_config.jl")

println("""
╔════════════════════════════════════════════════════════════╗
║   Batch Processing: Multiple Droop Parameters             ║
║   Using Refactored Structured Workflow                    ║
╚════════════════════════════════════════════════════════════╝
""")

# ===== Configuration =====
const DROOP_PARAMETERS = collect(range(33, 40; length=20))

try
    # ===== Step 1: Create Configurations =====
    println("\n[1/4] Loading configurations...")
    controller_config = converter_formming_configuations()
    controller_cfg = ControllerConfig(
        controller_config["VSM"]["control_parameters"],
        controller_config["Droop"]["control_parameters"]
    )
    
    # ===== Step 2: Create Computation Config =====
    println("[2/4] Setting up computation parameters...")
    comp_cfg = create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0)
    
    # ===== Step 3: Execute Batch Workflow =====
    println("[3/4] Processing $(length(DROOP_PARAMETERS)) droop parameters...")
    println("      (This may take a moment...)\n")
    
    combined_plot, vertices_matrix = execute_batch_workflow(DROOP_PARAMETERS, comp_cfg, controller_cfg)
    
    # ===== Step 4: Save Results =====
    println("\n[4/4] Saving results...")
    
    # Ensure output directory exists
    if !isdir("fig")
        mkdir("fig")
    end
    if !isdir("res")
        mkdir("res")
    end
    
    # Display the combined plot
    display(combined_plot)
    
    # Save plots
    Plots.savefig(combined_plot, joinpath(pwd(), "fig/batch_output_plot.png"))
    Plots.savefig(combined_plot, joinpath(pwd(), "fig/batch_output_plot.pdf"))
    
    # Save vertices
    write_vertices_to_file(vertices_matrix, pwd(), OUTPUT_REL_PATH)
    
    # Print summary
    println("""
    ✓ Batch workflow completed successfully!
    
    Summary:
      - Droop parameters processed: $(length(DROOP_PARAMETERS))
      - Droop range: $(minimum(DROOP_PARAMETERS)) to $(maximum(DROOP_PARAMETERS))
      - Total vertices: $(size(vertices_matrix, 1))
      - Plots saved to:
        * fig/batch_output_plot.png
        * fig/batch_output_plot.pdf
      - Vertices saved to: res/all_vertices.txt
      
    Next step:
      - Call plot_polygon_figures("res", "res") to visualize the polygon
    """)
    
    # Optional: Generate polygon visualization
    println("\nGenerating polygon visualization...")
    plot_polygon_figures("res", "res")
    println("✓ Polygon visualization complete!")
    
catch e
    println("\n✗ Error during batch workflow execution:")
    if isa(e, ValidationError)
        println("  Validation Error: $(e.message)")
    else
        println("  $(typeof(e).name): $(e)")
        println("\nStacktrace:")
        Base.showerror(stdout, e)
    end
end
