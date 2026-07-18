using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions
using Plots

println("============================================================")
println("Running Case Studies for Multi-Area Frequency Security Region")
println("============================================================")

# Create figures directory if not exists
mkpath("fig/multi_area")

# Helper function to rename the generated files for a specific case
function rename_case_files(case_name::String, decoupling_factor::Float64)
    files_to_rename = [
        ("multiarea_comparison", "comparison"),
        ("multiarea_overlay", "overlay"),
        ("multiarea_summary", "summary"),
        ("multiarea_factor$(decoupling_factor)_comparison", "factor$(decoupling_factor)_comparison"),
        ("multiarea_factor$(decoupling_factor)_overlay", "factor$(decoupling_factor)_overlay"),
        ("multiarea_comparison_dynamic", "comparison_dynamic"),
        ("multiarea_overlay_dynamic", "overlay_dynamic"),
        ("multiarea_capacity_impact", "capacity_impact"),
        ("multiarea_stiffness_impact", "stiffness_impact"),
        ("multiarea_mutual_support_trajectories", "mutual_support_trajectories")
    ]
    
    for (old_name, new_suffix) in files_to_rename
        for ext in [".pdf", ".png"]
            old_path = joinpath("fig", "multi_area", "$(old_name)$(ext)")
            new_path = joinpath("fig", "multi_area", "$(case_name)_$(new_suffix)$(ext)")
            if isfile(old_path)
                mv(old_path, new_path, force=true)
                println("Renamed: $old_path -> $new_path")
            end
        end
    end
end

println("\n>>> Running four explicit H-D Nadir / tie-line boundary cases...")
case_results = run_hd_fsr_case_studies()
for r in case_results
    println("$(r.label): feasible H-D area = $(round(r.boundary.area, digits=3)) p.u.·s")
    println("  figure: $(r.path)")
end

println("\nAll case studies completed successfully!")
println("Plots have been saved to fig/multi_area/")
println("Vertices have been saved to res/multi_area/")
println("============================================================")
