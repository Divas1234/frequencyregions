include("src/environment_config.jl")

# Constants for analysis
const DROOP_PARAMETERS = collect(range(33, 40; length = 20))

# --- Main Procedural Process ---
final_plot, p1, p2, p3, p4 = draw_hdregions(DROOP_PARAMETERS)

# Save and Export
output_dir = joinpath(pwd(), "fig")
isdir(output_dir) || mkpath(output_dir)

save_path_png = joinpath(output_dir, "IEEE_Inertia_Damping_Comparison.png")
save_path_pdf = joinpath(output_dir, "IEEE_Inertia_Damping_Comparison.pdf")

Plots.savefig(final_plot, save_path_png)
Plots.savefig(final_plot, save_path_pdf)

println("✓ IEEE-style comparison figure saved to: $save_path_pdf")

# Display in environment
display(final_plot)

# 15320306715

