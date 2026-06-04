using Pkg
Pkg.activate(".Pkg/")

include("src/environment_config.jl")

println("\n=== Multi-Area Frequency Security Region Analysis ===")
println("=== Method: Decoupled Approximation (Option A) ===")

system = build_ieee_2area_kundur()

println("\n--- Uncoupled Baseline (factor=0.0) ---")
baseline = run_multiarea_analysis(; system = system, decoupling_factor = 0.0)
for r in baseline.results
    nv = length(r.result.vertices)
    fp = round.(r.result.fitting_parameters, digits = 3)
    println("  Area $(r.area_id): ΔP=$(r.effective_disturbance), $(nv) vertices, fit=[$(fp[1]), $(fp[2]), $(fp[3])]")
end

println("\n--- With Tie-Line Coupling (factor=0.1) ---")
coupled = run_multiarea_analysis(; system = system, decoupling_factor = 0.1)
for r in coupled.results
    nv = length(r.result.vertices)
    fp = round.(r.result.fitting_parameters, digits = 3)
    status = nv > 0 ? "FEASIBLE" : "INFEASIBLE"
    println("  Area $(r.area_id): ΔP_eff=$(round(r.effective_disturbance,digits=2)), $(nv) vertices, $status, fit=[$(fp[1]), $(fp[2]), $(fp[3])]")
end

display(coupled.all_vertices)

println("\n--- Saving Plots ---")
try
    p_comp = plot_multiarea_comparison(coupled.results, create_computation_config(2:0.25:15, 2.5, 12.0, 0))
    Plots.savefig(p_comp, "fig/multiarea_comparison.pdf")
    println("  -> fig/multiarea_comparison.pdf")
    p_over = plot_feasible_region_overlay(coupled.results, create_computation_config(2:0.25:15, 2.5, 12.0, 0))
    Plots.savefig(p_over, "fig/multiarea_overlay.pdf")
    println("  -> fig/multiarea_overlay.pdf")
catch e
    println("  Could not save: $e")
end

println("\n=== Done ===")
