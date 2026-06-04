# Parametric sweep script for multi-area frequency security region analysis.
# Sweeps decoupling factors to simulate different tie-line disturbance conditions.

using Pkg
Pkg.activate(".Pkg/")

include("../src/environment_config.jl")

println("\n=== Multi-Area Frequency Security Region Parametric Sweep ===")

system = build_ieee_2area_kundur()
factors = [0.0, 0.05, 0.10, 0.15, 0.20]

# Pre-allocate sweep summary logging
summary_log = []

for factor in factors
    println("\n------------------------------------------------------------")
    println("  Running Analysis for Decoupling Factor = $factor")
    println("------------------------------------------------------------")
    
    # Run the multiarea analysis
    res = run_multiarea_analysis(;
        system = system,
        decoupling_factor = factor,
        output_path = "res/sweep_vertices_factor_$(factor).txt"
    )
    
    # Save the academic plots
    comparison_pdf = "fig/sweep_factor_$(factor)_comparison.pdf"
    overlay_pdf = "fig/sweep_factor_$(factor)_overlay.pdf"
    
    try
        Plots.savefig(res.comparison_plot, comparison_pdf)
        println("  -> Saved comparison plot to: $comparison_pdf")
        Plots.savefig(res.overlay_plot, overlay_pdf)
        println("  -> Saved overlay plot to: $overlay_pdf")
    catch e
        @warn "Could not save figures for factor=$factor: $e"
    end
    
    # Extract numerical results for the report
    area_summaries = []
    for ar in res.results
        nv = length(ar.result.vertices)
        min_h = nv > 0 ? minimum([v[3] for v in ar.result.vertices]) : NaN
        max_h = nv > 0 ? maximum([v[3] for v in ar.result.vertices]) : NaN
        push!(area_summaries, (
            area_id = ar.area_id,
            eff_dist = ar.effective_disturbance,
            n_vertices = nv,
            min_inertia = min_h,
            max_inertia = max_h,
            fit = ar.result.fitting_parameters
        ))
    end
    push!(summary_log, (factor = factor, areas = area_summaries))
end

# Print structured table for copy-pasting into the markdown report
println("\n\n" * "="^70)
println("              PARAMETRIC SWEEP RESULTS SUMMARY TABLE")
println("="^70)
println("Factor | Area | Eff. ΔP | Vertices | Min Inertia | Max Inertia | Quadratic Fit")
println("-"^70)
for entry in summary_log
    f = entry.factor
    for a in entry.areas
        fit_str = "[$(round(a.fit[1], digits=2)), $(round(a.fit[2], digits=2)), $(round(a.fit[3], digits=2))]"
        @printf("%.2f   |  %d   |  %.2f    |   %d     |    %.2f     |    %.2f     | %s\n",
                f, a.area_id, a.eff_dist, a.n_vertices, a.min_inertia, a.max_inertia, fit_str)
    end
end
println("="^70 * "\n")
