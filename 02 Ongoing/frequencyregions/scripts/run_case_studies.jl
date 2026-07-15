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

# Case 1: Symmetric baseline system
println("\n>>> Running Case 1: Symmetric Baseline System...")
case1_system = build_ieee_2area_kundur()
result1 = mainfun_multiarea(
    system=case1_system,
    output_path="res/multi_area/case1_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case1_symmetric", 0.1)

# Case 2: Asymmetric Weak Disturbed & Strong Healthy system
println("\n>>> Running Case 2: Asymmetric Weak Disturbed & Strong Healthy System...")
case2_system = build_asymmetric_resources_system()
result2 = mainfun_multiarea(
    system=case2_system,
    output_path="res/multi_area/case2_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case2_weak_disturbed", 0.1)

# Case 3: Asymmetric Strong Disturbed & Weak Healthy system
println("\n>>> Running Case 3: Asymmetric Strong Disturbed & Weak Healthy System...")
case3_system = build_strong_disturbed_weak_healthy_system()
result3 = mainfun_multiarea(
    system=case3_system,
    output_path="res/multi_area/case3_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case3_strong_disturbed", 0.1)

println("\nAll case studies completed successfully!")
println("Plots have been saved to fig/multi_area/")
println("Vertices have been saved to res/multi_area/")
println("============================================================")
