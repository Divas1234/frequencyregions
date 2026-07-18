"""
    multi_area/fsr_case_studies.jl

H-D security-domain construction for a two-area contingency.  The Nadir
boundary is calculated from the capacity-clamped dynamic model; the tie-line
boundary uses the corresponding unclamped model and is therefore the locus
`max(abs(P_tie)) = C12`.  Their intersection, together with the ROCOF floor,
forms the physically feasible closed region.
"""

const FSR_CASE_LABELS = (
    "Case 1: strong / strong",
    "Case 2: weak disturbed / strong healthy",
    "Case 3: strong disturbed / weak healthy",
    "Case 4: weak / weak",
)

const FSR_CASE_OUTPUT_DIRS = (
    "case1_strong_strong",
    "case2_weak_disturbed_strong_healthy",
    "case3_strong_disturbed_weak_healthy",
    "case4_weak_weak",
)

"""Return the prescribed two-area system for one of the four FSR cases."""
function build_fsr_case_system(case_id::Int)
    case_id == 1 && return build_strong_regulation_both_areas_system()
    case_id == 2 && return build_asymmetric_resources_system()
    case_id == 3 && return build_strong_disturbed_weak_healthy_system()
    case_id == 4 && return build_weak_regulation_both_areas_system()
    throw(ArgumentError("case_id must be in 1:4"))
end

function _fsr_rocof_floor(area::AreaParameters)
    return 0.5 * area.power_deviation * PERCENTAGE_BASE / (area.rocof_threshold * FREQUENCY_BASE)
end

function _first_tieline(system::MultiAreaSystem)
    isempty(system.tie_lines) && throw(ArgumentError("FSR analysis requires one tie-line."))
    return system.tie_lines[1]
end

"""
    calculate_hd_fsr_boundaries(system; damping_values=2.5:0.25:12.0, h_max=30.0)

Calculates lower Nadir/ROCOF and upper tie-line boundaries for Area 1, their
intersections, and the area of their closed intersection.  `nadir_h` is the
minimum secure inertia; `tie_h` is the largest inertia before the *unclamped*
tie-line response reaches its transfer limit.
"""
function calculate_hd_fsr_boundaries(
    system::MultiAreaSystem;
    damping_values::AbstractVector{<:Real} = collect(2.5:0.25:12.0),
    h_max::Float64 = 30.0,
    t_max::Float64 = 10.0,
    dt::Float64 = 0.01,
)
    length(system.areas) == 2 || throw(ArgumentError("FSR analysis currently supports exactly two areas."))
    a1, a2 = system.areas
    tl = _first_tieline(system)
    d = Float64.(damping_values)
    rocof_h = _fsr_rocof_floor(a1)
    nadir_h = similar(d)
    tie_h = similar(d)

    for i in eachindex(d)
        nadir_h[i] = find_critical_inertia_nadir(
            d[i], a1.droop, a1.time_constant, a1.factorial_coefficient, a1.power_deviation,
            a2.initial_inertia, d[i], a2.droop, a2.time_constant, a2.factorial_coefficient, 0.0,
            tl.synchronizing_coeff, tl.capacity, a1.nadir_threshold, a2.nadir_threshold;
            H_max_search=h_max, tol=1e-3, t_max=t_max, dt=dt,
        )
        tie_h[i] = find_critical_inertia_tieline(
            d[i], a1.droop, a1.time_constant, a1.factorial_coefficient, a1.power_deviation,
            a2.initial_inertia, d[i], a2.droop, a2.time_constant, a2.factorial_coefficient, 0.0,
            tl.synchronizing_coeff, tl.capacity;
            H_max_search=h_max, tol=1e-3, t_max=t_max, dt=dt,
        )
    end

    lower_h = max.(nadir_h, rocof_h)
    margin = tie_h .- lower_h
    intersections = NamedTuple{(:damping, :inertia),Tuple{Float64,Float64}}[]
    for i in 1:length(d)-1
        if margin[i] == 0.0 || margin[i] * margin[i + 1] < 0.0
            weight = margin[i] == margin[i + 1] ? 0.0 : margin[i] / (margin[i] - margin[i + 1])
            d_cross = d[i] + weight * (d[i + 1] - d[i])
            h_cross = lower_h[i] + weight * (lower_h[i + 1] - lower_h[i])
            push!(intersections, (damping=d_cross, inertia=h_cross))
        end
    end

    widths = max.(margin, 0.0)
    area = sum(0.5 * (widths[i] + widths[i + 1]) * (d[i + 1] - d[i]) for i in 1:length(d)-1)
    return (
        damping=d, nadir_h=nadir_h, tie_h=tie_h, rocof_h=rocof_h,
        lower_h=lower_h, margin=margin, intersections=intersections, area=area, h_max=h_max,
    )
end

"""Plot explicit Nadir and tie-line boundaries and shade their feasible H-D intersection."""
function plot_hd_fsr_boundaries(case_id::Int, result; title::String=FSR_CASE_LABELS[case_id])
    d, lower, tie = result.damping, result.lower_h, result.tie_h
    finite_h = vcat(lower, tie)
    y_max = max(10.0, min(30.0, maximum(finite_h) * 1.08))
    p = Plots.plot(; xlabel="Equivalent damping D₁ (p.u.)", ylabel="Equivalent inertia H₁ (s)",
        title=title, xlims=(first(d), last(d)), ylims=(0.0, y_max), legend=:topright,
        framestyle=:box, grid=true, gridalpha=0.15, size=(600, 420))

    # 1. Fill Nadir/ROCOF Violation Region (Unsafe - Soft Blue)
    Plots.plot!(p, Plots.Shape(vcat(d, reverse(d)), vcat(fill(0.0, length(d)), reverse(lower)));
        color=:royalblue, fillalpha=0.06, linecolor=:transparent, label="Nadir/ROCOF Unsafe")

    # 2. Fill Tie-line Overload Region (Unsafe - Soft Red)
    tie_clamped = min.(tie, y_max)
    Plots.plot!(p, Plots.Shape(vcat(d, reverse(d)), vcat(tie_clamped, fill(y_max, length(d))));
        color=:firebrick, fillalpha=0.06, linecolor=:transparent, label="Tie-line Unsafe")

    # 3. Fill Feasible Region (Safe - Green)
    feasible = findall(result.margin .>= 0.0)
    if length(feasible) >= 2
        ds, lows, ups = d[feasible], lower[feasible], tie[feasible]
        Plots.plot!(p, Plots.Shape(vcat(ds, reverse(ds)), vcat(lows, reverse(ups)));
            color=:seagreen, fillalpha=0.22, linecolor=:transparent, label="Feasible FSR")

        # Dynamic annotation inside Feasible Region
        mid_idx = div(length(feasible), 2)
        x_c = ds[mid_idx]
        y_c = 0.5 * (lows[mid_idx] + ups[mid_idx])
        Plots.annotate!(p, x_c, y_c, Plots.text("Feasible FSR", 9, :bold, :darkgreen, :center))
    end

    # 4. Plot Boundary Curves
    Plots.plot!(p, d, result.nadir_h; color=:royalblue, lw=2.5, label="Nadir limit (lower boundary)")
    Plots.plot!(p, d, fill(result.rocof_h, length(d)); color=:black, lw=1.5, linestyle=:dot, label="ROCOF floor")
    Plots.plot!(p, d, tie; color=:firebrick, lw=2.5, label="Tie-line limit (upper boundary)")

    # 5. Plot Inertia Ceiling
    Plots.hline!(p, [result.h_max]; color=:gray45, lw=1.2, linestyle=:dash, label="Inertia ceiling")

    # 6. Plot Intersections and Projection Lines
    for x in result.intersections
        # Dotted lines to axes
        Plots.plot!(p, [x.damping, x.damping], [0.0, x.inertia]; color=:black, lw=1.0, linestyle=:dash, label="")
        Plots.plot!(p, [first(d), x.damping], [x.inertia, x.inertia]; color=:black, lw=1.0, linestyle=:dash, label="")

        # Highlight point
        Plots.scatter!(p, [x.damping], [x.inertia]; color=:black, marker=:diamond, markersize=6, label="Intersection")
        
        # Label coordinates (shifting label placement to avoid line overlaps)
        x_offset = (last(d) - first(d)) * 0.03
        y_offset = y_max * 0.03
        Plots.annotate!(p, x.damping + x_offset, x.inertia + y_offset, 
            Plots.text("($(round(x.damping, digits=2)), $(round(x.inertia, digits=2)))", 8, :bold, :black, :left))
    end

    # 7. Dynamic text annotations for unsafe regions to avoid overlapping
    # Nadir violation label placement
    nadir_heights = lower
    max_nadir_val, max_nadir_idx = findmax(nadir_heights)
    if max_nadir_val > 1.5
        x_n = d[max_nadir_idx]
        y_n = 0.5 * max_nadir_val
        Plots.annotate!(p, x_n, y_n, Plots.text("Nadir Violation", 8, :darkblue, :center))
    end

    # Tie-line overload label placement
    tieline_heights = y_max .- tie_clamped
    max_tie_val, max_tie_idx = findmax(tieline_heights)
    if max_tie_val > 1.5
        x_t = d[max_tie_idx]
        y_t = 0.5 * (tie_clamped[max_tie_idx] + y_max)
        Plots.annotate!(p, x_t, y_t, Plots.text("Tie-line Overload", 8, :red, :center))
    end

    return p
end

"""Run, save, and return the four prescribed H-D multi-boundary FSR cases."""
function run_hd_fsr_case_studies(; output_dir::String="fig/multi_area", damping_values=collect(2.5:0.25:12.0))
    mkpath(output_dir)
    results = NamedTuple[]
    for case_id in 1:4
        system = build_fsr_case_system(case_id)
        boundary = calculate_hd_fsr_boundaries(system; damping_values=damping_values)
        plot = plot_hd_fsr_boundaries(case_id, boundary)
        case_dir = joinpath(output_dir, FSR_CASE_OUTPUT_DIRS[case_id])
        mkpath(case_dir)
        path = joinpath(case_dir, "hd_fsr_boundaries.png")
        Plots.savefig(plot, path)
        push!(results, (case_id=case_id, label=FSR_CASE_LABELS[case_id], system=system, boundary=boundary, plot=plot, path=path))
    end
    return results
end
