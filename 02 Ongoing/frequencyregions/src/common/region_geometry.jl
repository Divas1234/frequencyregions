function sub_data_visualization(
    damping, min_inertia, max_inertia, inertia_updown_bindings,
    extreme_inertia, nadir_vector, inertia_vector, selected_ids, min_damping, max_damping, droop, fittingparameters,)

    fillarea = zeros(length(damping))
    for i in eachindex(damping)
        fitted_value = fittingparameters[1] .+ fittingparameters[2] .* damping[i] .+
                       fittingparameters[3] .* damping[i] .^ 2
        fillarea[i] = max(fitted_value, min_inertia)
    end

    bounds_mat = collect(inertia_updown_bindings)
    if size(bounds_mat, 2) != 2
        throw(DimensionMismatch("inertia_updown_bindings must have 2 columns"))
    end

    try
        # Initialize plot with publication-quality theme
        sy1 = Plots.plot(;
            framestyle=:box,
            fontfamily=PLOT_FONT_FAMILY,
            tickdirection=:out,
            grid=true,
            gridalpha=0.12,
            gridcolor=:grey80,
            xlabel="Damping, D (p.u.)", 
            ylabel="Inertia, H (s)",
            title="", # No title for publication
            titlefontsize=10,
            guidefontsize=9,
            tickfontsize=8,
            legendfontsize=8,
            legend=:topright,
            fg_legend=:transparent,
            bg_legend=:transparent,
            size=(350, 300),
            left_margin=12Plots.px,
            bottom_margin=10Plots.px,
            top_margin=5Plots.px,
            right_margin=8Plots.px,
            ylims=(0, 1.05 * maximum(bounds_mat[:, 1]))
        )

        # 1. Fill Feasible Region
        idx_range = findall(d -> min_damping <= d <= max_damping, damping)
        if !isempty(idx_range)
            damp_sub = collect(damping[idx_range])
            top_sub = bounds_mat[idx_range, 1]
            bottom_sub = [min(top_sub[i], max(bounds_mat[idx_range[i], 2], min_inertia, 
                          fittingparameters[1] + fittingparameters[2] * damping[idx_range[i]] + 
                          fittingparameters[3] * damping[idx_range[i]]^2)) for i in eachindex(idx_range)]
            
            Plots.plot!(sy1, damp_sub, top_sub;
                fillrange = bottom_sub,
                fillalpha = 0.22,
                fillcolor = COLOR_FEASIBLE_ISO,
                lw = 0,
                label = "Feasible Region"
            )
        end

        # 2. Draw boundary curves
        # Upper Bound (ζ = 1)
        Plots.plot!(sy1, collect(damping), bounds_mat[:, 1];
            lw=1.5, label="Upper bound (ζ = 1)", color=COLOR_UPPER_BOUND)

        # Lower Bound (ζ = 1)
        Plots.plot!(sy1, collect(damping), bounds_mat[:, 2];
            lw=1.5, label="Lower bound (ζ = 1)", color=COLOR_LOWER_BOUND, linestyle=:dash)

        # Nadir Fit Boundary
        Plots.plot!(sy1, collect(damping),
            fittingparameters[1] .+ fittingparameters[2] .* damping .+
            fittingparameters[3] .* damping .^ 2;
            lw=1.5, label="Nadir fit boundary", color=COLOR_FIT_CURVE, linestyle=:dashdot)

        # ROCOF limit
        Plots.hline!(sy1, [min_inertia]; lw=1.5, label="ROCOF limit", color=COLOR_ROCOF_LIMIT, linestyle=:dot)

        # Max Inertia
        max_inertia_vec = isa(max_inertia, AbstractArray) ? vec(max_inertia) : [max_inertia]
        if length(max_inertia_vec) > 1
            Plots.plot!(sy1, collect(damping), max_inertia_vec; lw=1.2, label="Max inertia limit", color=:orange, linestyle=:dash)
        else
            Plots.hline!(sy1, max_inertia_vec; lw=1.2, label="Max inertia limit", color=:orange, linestyle=:dash)
        end

        # Damping search limits
        Plots.vline!(sy1, [min_damping]; lw=1.0, label="Damping limits", color=COLOR_DAMPING_BOUNDS, linestyle=:dot)
        Plots.vline!(sy1, [max_damping]; lw=1.0, label="", color=COLOR_DAMPING_BOUNDS, linestyle=:dot)

        return sy1
    catch e
        @warn "Error in sub_data_visualization: $e"
        return Plots.plot(collect(damping), bounds_mat[:, 1]; label="upper_bound")
    end
end


function calculate_vertex(damping_range, inertia_updown_bindings, fittingparameters,
    min_inertia, max_inertia, min_damping, max_damping, droop,)

    if length(fittingparameters) < 3
        error("fittingparameters must have at least 3 elements")
    end
    if isempty(damping_range)
        error("damping_range cannot be empty")
    end

    max_damping_index_raw = findfirst(x -> x >= max_damping, damping_range)
    min_damping_index_raw = findfirst(x -> x >= min_damping, damping_range)

    max_damping_index = isnothing(max_damping_index_raw) ? length(damping_range) : max_damping_index_raw
    min_damping_index = isnothing(min_damping_index_raw) ? 1 : min_damping_index_raw

    if min_damping_index > max_damping_index
        min_damping_index, max_damping_index = max_damping_index, min_damping_index
    end

    indices = min_damping_index:max_damping_index
    if isempty(indices)
        return Tuple{Float64,Float64,Float64}[]
    end

    damp_vals = damping_range[indices]
    bounds_mat = collect(inertia_updown_bindings)
    upper_bounds = bounds_mat[indices, 1]
    lower_bounds = bounds_mat[indices, 2]

    fit_curve = fittingparameters[1] .+ fittingparameters[2] .* damp_vals .+
                fittingparameters[3] .* damp_vals .^ 2

    vertices = Tuple{Float64,Float64,Float64}[]

    for i in eachindex(damp_vals)
        h_bot = max(lower_bounds[i], min_inertia, fit_curve[i])
        push!(vertices, (Float64(droop), Float64(damp_vals[i]), Float64(h_bot)))
    end

    for i in length(damp_vals):-1:1
        push!(vertices, (Float64(droop), Float64(damp_vals[i]), Float64(upper_bounds[i])))
    end

    return vertices
end

function vertices_to_matrix(vertices::AbstractVector)
    if isempty(vertices)
        @warn "Input 'vertices' is empty. Returning an empty matrix."
        return Matrix{Float64}(undef, 0, 3)
    end

    first_element = first(vertices)
    if isa(first_element, AbstractVector) && !isempty(first_element) && isa(first(first_element), Tuple)
        first_tuple_length = length(first(first_element))
        if first_tuple_length != 3
            throw(ArgumentError("Tuples in 'vertices' must have length 3 (droop, damping, inertia)."))
        end

        total_points = sum(length(v) for v in vertices)
        matrix = Matrix{Float64}(undef, total_points, 3)

        current_row = 1
        for sub_vertices in vertices
            for (i, vertex) in enumerate(sub_vertices)
                matrix[current_row+i-1, :] = collect(vertex)
            end
            current_row += length(sub_vertices)
        end

        return matrix
    end

    throw(ArgumentError("Input 'vertices' must be a vector of vectors of tuples."))
end

function write_vertices_to_file(matrix::Matrix, base_path::String, rel_path::String)
    output_file = joinpath(base_path, rel_path)
    mkpath(dirname(output_file))

    open(output_file, "w") do io
        for row in eachrow(matrix)
            println(io, join(row, "\t"))
        end
    end

    println("Vertices saved to: $output_file")
end
