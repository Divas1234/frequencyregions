using Plots
include("inertia_damping_regressionrelations.jl")

"""
	data_visualization(damping, inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids; min_inertia=0.0, max_inertia=1.0)

Visualizes the relationship between damping, inertia, and nadir distribution.

# Arguments
- `damping`: A vector of damping values (p.u.).
- `inertia_updown_bindings`: A matrix where each row represents a damping value, and the two columns represent the upper and lower inertia bounds (p.u.).
- `extreme_inertia`: A vector of extreme inertia values (p.u.) corresponding to each damping value.
- `nadir_vector`: A matrix representing the nadir distribution.
- `inertia_vector`: A matrix representing the inertia distribution.
- `selected_ids`: (Not used in the current implementation, but kept for potential future use).
- `min_inertia`: The minimum inertia value (default: 0.0).
- `max_inertia`: The maximum inertia value (default: 1.0).

# Returns
- A Plots.Plot object containing the visualizations.
"""
function data_visualization(
    damping,
    inertia_updown_bindings,
    extreme_inertia,
    nadir_vector,
    inertia_vector,
    selected_ids,
    max_inertia,
    min_inertia = 0.0,
)

    # --- Plot 1: Extreme Inertia ---
    sp1 = plot(
        damping,
        extreme_inertia,
        lw = 3,
        framestyle = :box,
        ylims = (0, maximum(extreme_inertia)),
        xlabel = "damping / p.u.",
        ylabel = "max inertia / p.u.",
        title = "Extreme Inertia",
        label = "Extreme Inertia",
        legend = :topleft,
        grid = true,
    )
    plot!(
        sp1,
        damping,
        extreme_inertia,
        fillrange = inertia_updown_bindings[:, 1],
        fillalpha = 0.3,
        label = "Inertia Range",
        color = :skyblue,
    )

    # --- Plot 2: Nadir Distribution ---
    sp2 = heatmap(
        nadir_vector,
        framestyle = :box,
        xlabel = "Damping",
        ylabel = "nadir distribution",
        title = "Nadir Distribution",
        grid = false,
        colorbar_title = "Value",
    )

    # --- Plot 3: Inertia Distribution ---
    sp3 = heatmap(
        inertia_vector,
        framestyle = :box,
        xlabel = "Damping",
        ylabel = "inertia distribution",
        title = "Inertia Distribution",
        grid = false,
        colorbar_title = "Value",
    )

    # --- Fitting and Interaction Point Calculation ---
    fittingparameters = calculate_fittingparameters(extreme_inertia, damping)

    fillarea = zeros(length(damping))
    for i in eachindex(damping)
        fitted_value =
            fittingparameters[1] +
            fittingparameters[2] * damping[i] +
            fittingparameters[3] * damping[i]^2
        fillarea[i] = max(fitted_value, min_inertia)
    end

    fitted_curve =
        fittingparameters[1] .+ fittingparameters[2] .* damping .+
        fittingparameters[3] .* damping .^ 2
    seq = fitted_curve .- max_inertia

    interaction_point = if seq[1] > 0
        findfirst(x -> x < 0, seq)
    else
        findfirst(x -> x > 0, seq)
    end

    if isnothing(interaction_point)
        interaction_point = length(damping)
        @warn "No interaction point found. Setting interaction point to the end of the damping range."
    end

    # NOTE --- Plot 4: Inertia Bounds and Interaction ---

    # sy1 = plot(
    # 	damping, inertia_updown_bindings[:, 1],
    # 	framestyle = :box,
    # 	ylims = (0, maximum(inertia_updown_bindings[:, 1])),
    # 	xlabel = "Damping (p.u.)",
    # 	ylabel = "Inertia (p.u.)",
    # 	lw = 3,
    # 	label = "Upper Bound",
    # 	# title = "Inertia Bounds",
    # 	legend = :topleft,
    # 	grid = true
    # )
    # plot!(sy1, damping, inertia_updown_bindings[:, 2],
    # 	lw = 3,
    # 	label = "Lower Bound",
    # 	color = :forestgreen
    # )
    # plot!(sy1, damping, inertia_updown_bindings[:, 1],
    # 	fillrange = fillarea,
    # 	fillalpha = 0.3,
    # 	label = "Fill Area",
    # 	color = :skyblue
    # )

    # tem_interaction_point = Int64(interaction_point[1])
    # temp = damping[tem_interaction_point:end], max_inertia[tem_interaction_point:end]
    # plot!(sy1, temp,
    # 	fillrange = fillarea[tem_interaction_point:end],
    # 	fillalpha = 0.5,
    # 	label = "Interaction",
    # 	color = :red
    # )

    # plot!(sy1, damping, fitted_curve,
    # 	lw = 3,
    # 	label = "Fitted Curve",
    # 	color = :purple
    # )
    # hline!(sy1, [min_inertia],
    # 	lw = 3,
    # 	label = "Min Inertia",
    # 	linestyle = :dash
    # )
    # plot!(sy1, damping, max_inertia,
    # 	lw = 3,
    # 	label = "Max Inertia",
    # 	color = :orange
    # )

    tem_interaction_point = Int64(interaction_point[1])
    temp = damping[tem_interaction_point:end], max_inertia[tem_interaction_point:end]

    l = @layout [
        a{0.2h}    # 上部分占 33% 高度
        b{0.7h}    # 中间部分占 34% 高度
        c{0.1h}
    ]

    sy1 = plot(
        plot(
            damping,
            inertia_updown_bindings[:, 1],
            # framestyle = :box,
            ylims = (15, 23),           # 调整上限范围
            yticks = 15:5:20,           # 设置均匀刻度
            xlabel = "",               # 移除 xlabel
            ylabel = "",              # 移除单独的 ylabel
            lw = 3,
            showaxis = :y,
            bottom_margin = -15Plots.px,
            # framestyle = :box,
            label = "Upper Bound",
            legend = :none,      # Changed from false to :none
            grid = true,
        ),
        begin
            p2 = plot(
                damping,
                inertia_updown_bindings[:, 1],
                fillrange = fillarea,
                fillalpha = 0.3,
                ylims = (5, 15),         # 保持中间范围
                yticks = 5:2:15,         # 设置均匀刻度
                showaxis = :y,
                bottom_margin = -15Plots.px,
                top_margin = -15Plots.px,
                label = "Fill Area",
                color = :skyblue,
                xlabel = "Damping (p.u.)",
                ylabel = "Inertia (p.u.)",
                grid = true,
            )

            # Add additional layers to p2
            plot!(
                p2,
                temp,
                # max_inertia_temp,
                fillrange = fillarea[tem_interaction_point:end],
                fillalpha = 0.5,
                label = "Interaction",
                color = :red,
            )
            plot!(
                p2,
                damping,
                fitted_curve,
                lw = 3,
                label = "Fitted Curve",
                color = :purple,
            )
            hline!(p2, [min_inertia], lw = 3, label = "Min Inertia", linestyle = :dash)
            plot!(p2, damping, max_inertia, lw = 3, label = "Max Inertia", color = :orange)
            p2
        end,
        plot(
            damping,
            inertia_updown_bindings[:, 2],
            lw = 3,
            ylims = (-2, 5),             # 调整下限范围
            yticks = 0:5:5,             # 设置均匀刻度
            top_margin = -15Plots.px,
            label = "Lower Bound",
            color = :forestgreen,
            xlabel = "Damping (p.u.)",
            ylabel = "",               # 移除单独的 ylabel
            grid = true,
        ),
        layout = l,
        size = (400, 300),
        left_margin = 30Plots.px,    # 调整左边距
        ylabel = "Inertia (p.u.)",    # 添加全局 ylabel
        legend = :topright,     # Main plot legend
        legendfontsize = 8,     # Adjust legend font size
        legend_column = 2,       # Arrange legend in 2 columns
    )

    # --- Combine Plots ---
    p1 = plot(sp2, sp3, sp1, sy1, layout = (2, 2), size = (1000, 800))

    return p1
end
