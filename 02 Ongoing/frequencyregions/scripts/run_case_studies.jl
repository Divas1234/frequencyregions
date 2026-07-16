using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using FrequencyRegions
using Plots

println("============================================================")
println("Running Unified Case Studies for Multi-Area Frequency Security Region")
println("============================================================")

# Create figures directory if not exists
mkpath("fig/multi_area")
mkpath("res/multi_area")

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

# Case 1: Both Strong System
println("\n>>> Running Case 1: Symmetric Both Strong System...")
case1_system = build_symmetric_strong_system()
result1 = mainfun_multiarea(
    system=case1_system,
    output_path="res/multi_area/case1_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case1_both_strong", 0.1)

# Case 2: Asymmetric Strong Disturbed & Weak Healthy System
println("\n>>> Running Case 2: Asymmetric Strong Disturbed & Weak Healthy System...")
case2_system = build_strong_disturbed_weak_healthy_system()
result2 = mainfun_multiarea(
    system=case2_system,
    output_path="res/multi_area/case2_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case2_strong_disturbed_weak_healthy", 0.1)

# Case 3: Asymmetric Weak Disturbed & Strong Healthy System
println("\n>>> Running Case 3: Asymmetric Weak Disturbed & Strong Healthy System...")
case3_system = build_asymmetric_resources_system()
result3 = mainfun_multiarea(
    system=case3_system,
    output_path="res/multi_area/case3_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case3_weak_disturbed_strong_healthy", 0.1)

# Case 4: Both Weak System
println("\n>>> Running Case 4: Symmetric Both Weak System...")
case4_system = build_symmetric_weak_system()
result4 = mainfun_multiarea(
    system=case4_system,
    output_path="res/multi_area/case4_vertices.txt",
    decoupling_factor=0.1
)
rename_case_files("case4_both_weak", 0.1)


# Plotting overlay comparison for Area 1 across all 4 cases
println("\n>>> Generating comparative overlay plot for Area 1...")
p_compare = plot(; framestyle = :box,
    xlabel = "Damping, D (p.u.)", ylabel = "Inertia, H (s)",
    title = "Area 1 (Disturbed Area) Frequency Security Region",
    guidefontsize = 9, tickfontsize = 8, legendfontsize = 8,
    grid = true, gridalpha = 0.12, gridcolor = :grey80,
    legend = :topright, fg_legend = :transparent, bg_legend = :transparent,
    size = (550, 450)
)

cases_info = [
    ("Case 1: Both Strong", result1, :forestgreen),
    ("Case 2: Disturbed Strong, Healthy Weak", result2, :royalblue),
    ("Case 3: Disturbed Weak, Healthy Strong", result3, :orange),
    ("Case 4: Both Weak", result4, :crimson)
]

for (label, result, color) in cases_info
    area1_res = first(filter(ar -> ar.area_id == 1, result.dynamic_results))
    verts = area1_res.result.vertices
    if length(verts) >= 3
        damp_vals = [v[2] for v in verts]
        inert_vals = [v[3] for v in verts]
        plot!(p_compare, Shape(damp_vals, inert_vals);
            fillalpha = 0.20, label = label,
            color = color, lw = 2.0, linecolor = color
        )
    else
        # Just add a dummy line with label in the legend to denote empty/infeasible region
        plot!(p_compare, [0.0], [0.0]; label = "$label (Infeasible/Empty)", color = color, lw = 2.0, linestyle = :dash, alpha = 0.5)
    end
end

# Set visual range limits for consistency
xlims!(p_compare, (1.8, 15.2))
ylims!(p_compare, (0.0, 10.5))

savefig(p_compare, "fig/multi_area/cases_comparison.pdf")
savefig(p_compare, "fig/multi_area/cases_comparison.png")
println("Saved comparative plot to fig/multi_area/cases_comparison.pdf and .png")

println("\nAll case studies completed successfully!")
println("============================================================")
