"""
    multi_area_viz.jl

Visualization utilities for multi-area frequency security region analysis.
Generates side-by-side comparison plots and combined views.
"""

"""
    plot_multiarea_comparison(results::Vector{AreaResult}, config::ComputationConfig) -> Any

Creates a multi-panel figure comparing the feasible regions of all areas.

Each subplot shows:
- Upper/lower inertia bounds (from ζ < 1 constraint)
- Quadratic fit curve (from NADIR constraint)
- Min/max inertia limits (from ROCOF constraint)
- Damping boundary lines

# Returns
"""
function plot_multiarea_comparison(results::Vector{AreaResult}, config::ComputationConfig)
    n_areas = length(results)

    # Academic-friendly high-contrast color palette
    area_colors = [:royalblue, :crimson, :forestgreen, :darkorchid, :orange]
    plots = []

    for (idx, ar) in enumerate(results)
        r = ar.result
        ep = ar.effective_disturbance
        damp = collect(config.damping_range)

        bounds = collect(r.inertia_bounds)

        if isempty(bounds) || size(bounds, 2) < 2
            p = Plots.plot(; framestyle=:box,
                title="Area $(ar.area_id) (ΔP_eff = $(round(ep, digits=2)) p.u., INFEASIBLE)",
                xlabel="Damping D / p.u.", ylabel="Inertia H / s",
                titlefontsize=10, guidefontsize=10, tickfontsize=9,
                fontfamily="Computer Modern", grid=true, gridalpha=0.2, gridstyle=:dash)
            push!(plots, p)
            continue
        end

        p = Plots.plot(; framestyle=:box,
            title="Area $(ar.area_id) (ΔP_eff = $(round(ep, digits=2)) p.u.)",
            xlabel="Damping D / p.u.", ylabel="Inertia H / s",
            titlefontsize=10, guidefontsize=10, tickfontsize=9,
            legendfontsize=8, fontfamily="Computer Modern",
            grid=true, gridalpha=0.2, gridstyle=:dash,
            legend=:topright)

        max_inertia_vals = bounds[:, 1]

        # Shade Feasible Region with light opacity
        if !isempty(r.vertices)
            min_inertia = minimum([v[3] for v in r.vertices])

            # Compute fit curve values
            fit_curve = r.fitting_parameters[1] .+ r.fitting_parameters[2] .* damp .+
                        r.fitting_parameters[3] .* damp .^ 2

            # Find indices within [min_damping, max_damping]
            idx_range = findall(d -> config.min_damping <= d <= config.max_damping, damp)
            if !isempty(idx_range)
                damp_sub = damp[idx_range]
                top_sub = bounds[idx_range, 1]
                bottom_sub = [max(bounds[i, 2], min_inertia, fit_curve[i]) for i in idx_range]

                p = Plots.plot!(p, damp_sub, top_sub;
                    fillrange=bottom_sub, fillalpha=0.12, fillcolor=area_colors[idx],
                    lw=0, label="Feasible Region", color=area_colors[idx])
            end

            # Draw ROCOF limit horizontal line
            p = Plots.hline!(p, [min_inertia];
                lw=1.5, label="ROCOF limit", color=:darkred, linestyle=:dash, alpha=0.8)
        end

        if !isempty(max_inertia_vals)
            p = Plots.plot!(p, damp, max_inertia_vals;
                lw=2.0, label="Upper bound (ζ = 1)", color=area_colors[idx], alpha=0.9)
            p = Plots.plot!(p, damp, bounds[:, 2];
                lw=2.0, label="Lower bound (ζ = 1)",
                color=area_colors[idx], linestyle=:dash, alpha=0.9)
        end

        fit_curve = r.fitting_parameters[1] .+ r.fitting_parameters[2] .* damp .+
                    r.fitting_parameters[3] .* damp .^ 2
        p = Plots.plot!(p, damp, fit_curve;
            lw=1.8, label="Nadir quadratic fit",
            color=:black, linestyle=:dashdot)

        p = Plots.vline!(p, [config.min_damping]; lw=1.2, label="D damping bounds",
            color=:gray, linestyle=:dot, alpha=0.8)
        p = Plots.vline!(p, [config.max_damping]; lw=1.2, label="",
            color=:gray, linestyle=:dot, alpha=0.8)

        push!(plots, p)
    end

    if n_areas == 1
        return plots[1]
    elseif n_areas == 2
        return Plots.plot(plots[1], plots[2]; layout=(1, 2), size=(1200, 480),
            plot_title="Decoupled Multi-Area Feasible Regions Comparison",
            titlefont=(11, "Computer Modern"))
    else
        return Plots.plot(plots...; layout=(1, n_areas), size=(400 * n_areas, 480),
            plot_title="Decoupled Multi-Area Feasible Regions Comparison",
            titlefont=(11, "Computer Modern"))
    end
end


"""
    plot_feasible_region_overlay(results::Vector{AreaResult}, config::ComputationConfig) -> Any

Overlays the feasible region polygons of all areas on a single plot for
direct comparison. Polygon boundaries show the intersection of all constraints.

# Returns
- Plots.jl plot object
"""
function plot_feasible_region_overlay(results::Vector{AreaResult}, config::ComputationConfig)
    area_colors = [:royalblue, :crimson, :forestgreen, :darkorchid]
    area_alpha = 0.18

    p = Plots.plot(; framestyle=:box,
        xlabel="Damping D / p.u.", ylabel="Inertia H / s",
        title="Multi-Area Feasible Region Comparison (Overlay)",
        titlefontsize=11, guidefontsize=10, tickfontsize=9,
        legendfontsize=9, fontfamily="Computer Modern",
        grid=true, gridalpha=0.2, gridstyle=:dash,
        legend=:topright, size=(700, 480))

    for (idx, ar) in enumerate(results)
        verts = ar.result.vertices
        if length(verts) < 3
            continue
        end

        damp_vals = [v[2] for v in verts]
        inert_vals = [v[3] for v in verts]

        p = Plots.plot!(p, Plots.Shape(damp_vals, inert_vals);
            fillalpha=area_alpha, label="Area $(ar.area_id) (ΔP_eff = $(round(ar.effective_disturbance, digits=2)) p.u.)",
            color=area_colors[idx], lw=2.0, linecolor=area_colors[idx])
    end

    p = Plots.vline!(p, [config.min_damping]; lw=1.2, label="D damping bounds",
        color=:gray, linestyle=:dot)
    p = Plots.vline!(p, [config.max_damping]; lw=1.2, label="",
        color=:gray, linestyle=:dot)

    return p
end


"""
    plot_combined_summary(results::Vector{AreaResult}, config::ComputationConfig) -> Any

Creates a comprehensive 2x2 summary figure:
1. Top-left:  Area 1 detailed bounds
2. Top-right: Area 2 detailed bounds
3. Bottom-left:  Overlay of feasible polygons
4. Bottom-right: Parameter comparison table (text)

# Returns
- Plots.jl plot object
"""
function plot_combined_summary(results::Vector{AreaResult}, config::ComputationConfig)
    p_comparison = plot_multiarea_comparison(results, config)
    p_overlay = plot_feasible_region_overlay(results, config)

    if length(results) >= 2
        r1, r2 = results[1].result, results[2].result
        info_text = "Area 1: H = $(round(r1.fitting_parameters[1], digits=2)) + $(round(r1.fitting_parameters[2], digits=2))·D + $(round(r1.fitting_parameters[3], digits=2))·D²\n\nArea 2: H = $(round(r2.fitting_parameters[1], digits=2)) + $(round(r2.fitting_parameters[2], digits=2))·D + $(round(r2.fitting_parameters[3], digits=2))·D²\n\nVertices: A1=$(length(r1.vertices)), A2=$(length(r2.vertices))"

        p_info = Plots.plot(; framestyle=:box, title="Parameter Summary",
            xlims=(0, 1), ylims=(0, 1), showaxis=false,
            ticks=false)
        p_info = Plots.annotate!(0.5, 0.5, Plots.text(info_text, :black, 10))

        return Plots.plot(p_comparison, p_overlay, p_info;
            layout=(2, 2), size=(1400, 1000))
    end

    return Plots.plot(p_comparison, p_overlay; layout=(1, 2), size=(1400, 550))
end
