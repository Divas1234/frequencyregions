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
    y_max = max(1.0, min(30.0, maximum(finite_h) * 1.08))
    p = Plots.plot(; xlabel="Equivalent damping D₁ (p.u.)", ylabel="Equivalent inertia H₁ (s)",
        title=title, xlims=(first(d), last(d)), ylims=(0.0, y_max), legend=:topright,
        framestyle=:box, grid=true, gridalpha=0.15, size=(600, 420))
    feasible = findall(result.margin .>= 0.0)
    if length(feasible) >= 2
        ds, lows, ups = d[feasible], lower[feasible], tie[feasible]
        Plots.plot!(p, Plots.Shape(vcat(ds, reverse(ds)), vcat(lows, reverse(ups)));
            color=:seagreen, linecolor=:seagreen, fillalpha=0.20, label="Feasible FSR")
    end
    Plots.plot!(p, d, result.nadir_h; color=:royalblue, lw=2.5, label="Nadir limit (lower boundary)")
    Plots.plot!(p, d, fill(result.rocof_h, length(d)); color=:black, lw=1.5, linestyle=:dot, label="ROCOF floor")
    Plots.plot!(p, d, tie; color=:firebrick, lw=2.5, label="Tie-line limit (upper boundary)")
    if all(tie .>= result.h_max - 1e-3)
        Plots.hline!(p, [result.h_max]; color=:gray45, lw=1.2, linestyle=:dash,
            label="System-stability upper ceiling")
    end
    for x in result.intersections
        Plots.scatter!(p, [x.damping], [x.inertia]; color=:black, marker=:diamond, markersize=5,
            label="Boundary intersection")
        Plots.annotate!(p, x.damping, x.inertia, Plots.text("($(round(x.damping, digits=2)), $(round(x.inertia, digits=2)))", 8, :black))
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
