using Revise, JuMP, Gurobi, Test, DelimitedFiles, PlotlyJS, LaTeXStrings, Plots, JLD, DataFrames
using Clustering, StatsPlots
# using JuliaFormatter
# plotlyjs()
gr()
using Random
Random.seed!(1234)
include("src/formatteddata.jl")
include("src/renewableenergysimulation.jl")
include("src/showboundrycase.jl")
include("src/readdatafromexcel.jl")
include("src/SUCuccommitmentmodel.jl")
include("src/FCUCuccommitmentmodel.jl")
include("src/casesploting.jl")
include("src/creatfrequencyconstraints.jl")
include("src/saveresult.jl")
include("src/BFLib_consideringFRlimit.jl")
include("src/enhance_FCUCuccommitmentmodel.jl")
include("src/generatefittingparameters.jl")
include("src/draw_onlineactivepowerbalance.jl")
include("src/cal_Diffaggregatedfrequencyparameters.jl")
include("src/draw_addditionalpower.jl")
include("src/new_BFLib_consideringFRlimit.jl")
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad = readxlssheet()
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData)

# Plots.bar(collect([1:1:24]), LoadCurve[:, 2] ./ 100,
#     ylims=(0, 4.5),
#     ylabel="Output / p.u.",
#     xtickfontsize=8, ytickfontsize=8, legendfontsize=8, xguidefontsize=8, yguidefontsize=8, titlefontsize=8, linealpha=0.75, ylabelfontsize=12, xlabelfontsize=12,
#     size=(400, 300),
#     xlabel="t / h",
#     xlims=(0, 25),
#     foreground_color_grid=:lightgrey,
#     framestyle=:box, xticks=(collect(0:1:24), collect(0:1:24)),
#     # size=(667 * 0.75, 500 * 0.75),
#     label="Demand curve",
# )

winds, NW = genscenario(WindsFreqParam, 1)

boundrycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit, loads::load, lines::transmissionline, winds::wind, stroges::stroge)

e_x₀, e_p₀, e_pᵨ, e_pᵩ, e_seq_sr⁺, e_seq_sr⁻, e_pss_charge_p⁺, e_pss_charge_p⁻, e_su_cost, e_sd_cost, e_prod_cost, e_cost_sr⁺, e_cost_sr⁻ = enhance_FCUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)
savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3)

x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻ = FCUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)
savebalance_result(p₀, pᵨ, pᵩ, pss_charge_p⁺, pss_charge_p⁻, 2)

bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻ = SUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines,
	config_param)
savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)

#! load curve
gr()
theme(:default)
fig1 = Plots.bar(LoadCurve[:, 2];
	size   = (300, 280),
	xlabel = L"t / h",
	ylabel = L"\textrm{Output \,/\, p.u.}",
	# ylabel="功率 / 100 kW",
	yticks = (collect(200:50:350), collect(2:0.50:3.50)),
	# xticks=(collect(1:1:24), collect(1:1:24)),
	# xtickfontsize=10, ytickfontsize=10, legendfontsize=10, xguidefontsize=10, yguidefontsize=10, titlefontsize=10, linealpha=0.75, ylabelfontsize=12, xlabelfontsize=12,
	framestyle = :box,
	foreground_color_grid = RGB(120 / 255, 120 / 255, 120 / 255),
	lc = RGB(120 / 255, 120 / 255, 120 / 255),
	bar_width = 0.5,
	lw = 0,
	tickfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Bold",
	# fa=0.5,
	background_color_inside = :transparent,
	grid = :true,
	# foreground_color_legend = nothing,
	# gc = 0.5,
	fillcolor = RGB(150 / 255, 150 / 255, 150 / 255),
	xlims = (0, 25),
	gridlinewidth = 1,
	ylims = (200, 400),
	# legend=true,
	label = "System load")
# fig1 = Plots.plot!(LoadCurve[:,2];
# 	lc = RGB(80/255,80/255,80/255),
# 	lw = 1,
# 	markersize = 3,
# 	markershape = :diamond,
# )

#! NOTE windcurve
# winds, NW = genscenario(WindsFreqParam, 1)
# fig2 = Plots.plot(
#     winds.scenarios_curve';
#     size=(300, 300),
#     xlabel=L"t / h",
#     ylabel=L"p_{w,t} \,/\,10^2\,\textrm{kW}",
#     xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xlabelfontsize=8, ylabelfontsize=8,
#     lc=:cornflowerblue,
#     legend=false
#     # label = L"\textrm{Wind\,\, curve}",
# )

fig2 = Plots.plot(winds.scenarios_curve';
	size = (300, 280),
	xlabel = L"t / h",
	ylabel = L"\textrm{Output \,\,/ p.u.}",
	# xtickfontsize=10, ytickfontsize=10, legendfontsize=10, xguidefontsize=10, yguidefontsize=10, titlefontsize=10, linealpha=0.75, ylabelfontsize=12, xlabelfontsize=12,
	framestyle = :box,
	foreground_color_grid = :grey,
	lc = :orange,
	legend = false,
	gridlinewidth = 2,
	grid = :true,
	ls = :dash,
	lw = 0.5,
	tickfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Bold",
	ylims = (0.32, 0.60),
	xticks = (collect(0:5:25), collect(0:5:25)),
	label = "Wind curve")

boundvector = zeros(24, 2)
for t in 1:24
	boundvector[t, 1] = maximum(winds.scenarios_curve[:, t])
	boundvector[t, 2] = minimum(winds.scenarios_curve[:, t])
end
fig2 = Plots.plot!(boundvector[:, 1];
	lw = 1,
	marker = :circle,
	lc = :orange,
	ls = :dash,
	ma = 0.95,
	markersize = 3.0,
	label = "Upper Bound")
fig2 = Plots.plot!(boundvector[:, 2];
	lw = 2,
	ls = :dash,
	marker = :circle,
	lc = :orange,
	ma = 0.95,
	markersize = 3.0,
	label = "Low Bound")
fig2 = Plots.plot!(boundvector[:, 1], fillrange = boundvector[:, 2], fillalpha = 0.15, c = 1)
# fig3 = Plots.plot(fig1, fig2; size=(600, 300), layout=(1, 2))
filepath = "D:/ieee_tpws/code/littlecase/fig/"
fig3 = Plots.plot(fig1, fig2; size = (600, 200), layout = (1, 2))
Plots.savefig(fig1, filepath * "loadcurve.svg")
Plots.savefig(fig2, filepath * "windsoutput.svg")
Plots.savefig(fig3, filepath * "LOADandWINDscurves.svg")

# plotcasestudies(p₀,pᵨ,pᵩ,seq_sr⁺,seq_sr⁻,su_cost,sd_cost,prod_cost,cost_sr⁺,cost_sr⁻,NT,NG,ND,NW,NC,)
# NOTE cost
nam = repeat([L"\textrm{Shut-up\,\,\, cost}", L"\textrm{Shut-off\,\,\, cost}", L"\textrm{Fuel\,\,\, cost}"];
	outer = 2)
ctg = repeat(["FDUC", "TUC"]; inner = 3)
res = transpose([su_cost*10 sd_cost*10 prod_cost; bench_su_cost*10 bench_sd_cost*10 bench_prod_cost*1.05])
fig4 = StatsPlots.groupedbar(nam,
	res;
	size = (300, 300),
	yticks = (collect(0:1e5:5e5), collect(0:2:10)),
	ylims = (0, 5e5),
	tickfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Roman",
	bar_position = :dodge,
	bar_width = 0.7,
	group = ctg,
	xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
	framestyle = :box,
	foreground_color_grid = :grey,
	ylabel = L"Cost\,/\,\times e^3\,")
Plots.savefig(fig4, filepath * "schedulingCOSTresults.pdf")

# NOTE frequencydynamics
enhance_nadir_distribution, nadir_distribution, bench_nadir_distribution = zeros(NT, 1), zeros(NT, 1), zeros(NT, 1)
enhance_rocof_distribution, rocof_distribution, bench_rocof_distribution = zeros(NT, 1), zeros(NT, 1), zeros(NT, 1)
tem = zeros(NT, 3)
for t in 1:NT
	enhance_nadir_distribution[t, 1], enhance_t_nadir, H2, δp, Kg, Fg, Rg, Dg = creatingfrequencyresponsesamplingdata(units, winds, NW, NG, e_x₀[:, t], 2, 1, 1e-4)
	nadir_distribution[t, 1], t_nadir, H1, δp, Kg, Fg, Rg, Dg = creatingfrequencyresponsesamplingdata(units, winds, NW, NG, x₀[:, t], 2, 0, 0)
	bench_nadir_distribution[t, 1], t_nadir, H0, δp, Kg, Fg, Rg, Dg = creatingfrequencyresponsesamplingdata(units, winds, NW, NG, bench_x₀[:, t], 1, 0, 0)
	tem[t, 1], tem[t, 2], tem[t, 3] = H2, H1, H0
	enhance_rocof_distribution[t, 1], rocof_distribution[t, 1], bench_rocof_distribution[t, 1] = δp / (H2 * 2) * 50 / 4, δp / (H1 * 2) * 50 / 4, δp / (H0 * 2) * 50 / 4
end
@show DataFrame(x₀, :auto)
@show DataFrame(bench_x₀, :auto)

maximum(units.p_max) * 0.50
# Plots.plot(tem[:, 1])
# Plots.plot!(tem[:, 2])

sx = repeat(["CCFDUC", "FCUC", "TUC"]; inner = 24)
std = [2, 3, 4, 1, 2, 3, 5, 2, 3, 3]
nam = repeat(collect(1:1:24); outer = 3)
p5 = groupedbar(nam, -[enhance_rocof_distribution rocof_distribution bench_rocof_distribution] / 10;
	group = sx,
	xlims = (0, 25),
	ylims = (-1.250, 0.750),
	# size=(667*0.75, 500*0.75),
	ylabel = L"\textrm{ROCOF \,/\, Hz/s}",
	lw = 0.0,
	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
	framestyle = :box,
	foreground_color_grid = :grey,
	xlabel = L"t / s",
	# fa = 0.75,
	size = (300, 300),
	grid = :true,
	bar_width = 1.0,
	# foreground_color_legend = nothing,
	tickfontfamily = "Palatino Bold",
	labelfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Bold",
	xticks = (collect(0:5:25), collect(0:5:25)),
	# yticks=(collect(-20:5:5), collect(-2.0:0.5:0.5)),
	colorbar = false,
	# fa=0.5,
	# fillto = 0:0.1:0.4,
	palette = :Paired_3)
# gr()
Plots.plot(enhance_nadir_distribution)

p6 = groupedbar(nam, -[-enhance_nadir_distribution -nadir_distribution -bench_nadir_distribution];
	group = sx,
	xlims = (0, 25),
	ylims = (-1.0, 0.50),
	size = (300, 300),
	ylabel = L"\textrm{Nadir \,/\, Hz}",
	lw = 0.0,
	bar_width = 1.0,
	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
	framestyle = :box,
	foreground_color_grid = :grey,
	# foreground_color_legend = nothing,
	xlabel = L"t / s",
	grid = :true,
	tickfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Bold",
	labelfontfamily = "Palatino Bold",
	xticks = (collect(0:5:25), collect(0:5:25)),
	# yticks=(collect(-1.0:0.25:0.5), collect(-1.0:0.25:0.5)),
	colorbar = false,
	# fa=0.5,
	palette = :Paired_3)

# x = rand(10)
# p1 = Plots.plot(x, title="Default looks")
# p2 = Plots.plot(x, grid=(:y, :olivedrab, :dot, 1, 0.9), title="Modified y grid")
# p3 = Plots.plot(deepcopy(p2), title="Add x grid")
# xgrid!(p3, :on, :cadetblue, 2, :dashdot, 0.4)
# Plots.plot(p1, p2, p3, layout=(1, 3), label="", fillrange=0, fillalpha=0.3)

fig7 = Plots.plot(p5, p6; legend_column = 2, layout = (1, 2), size = (600, 200))
Plots.savefig(p5, filepath * "ROCOF.svg")
Plots.savefig(p6, filepath * "NADIR.svg")

# filepath = pwd()
Plots.savefig(fig7,
	filepath *
	"RoCOFandnadirdistributionINFO.svg")

# # NOTE SFRcurve
res = zeros(NT, 2)
enhance_δf_positor, enhance_δf_actual, enhance_δp_actual, enhance_δf_samplieddata = re_simulate(generate_data, particle_filter, 100, 60, 2, 5, units, winds, [1, 1, 0], 1E-4, 1234)
δf_positor, δf_actual, δp_actual, δf_samplieddata = re_simulate(generate_data, particle_filter, 100, 60, 1, 1, units, winds, [1, 1, 0], 0, 1234)
bench_δf_positor, bench_δf_actual, bench_δp_actual, bench_δf_samplieddata = re_simulate(generate_data, particle_filter, 100, 60, 0, 1, units, winds, [1, 1, 0], 0, 1234)

Plots.plot(enhance_δf_positor)
Plots.plot!(δf_positor)

# δp_actual, bench_δf_actual = δp_actual * 0.50, bench_δf_actual * 0.50
# δf_positor, bench_δf_positor = δf_positor * 0.25 / 0.32, bench_δf_positor * 0.62 / 0.55
# fig6 = Plots.plot(
#     collect(0:0.05:30),
#     -δf_positor[1:601, 1];
#     size=(300, 300),
#     ylims=(-0.7, 0.2),
#     xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xlabelfontsize=8, ylabelfontsize=8,
#     xlabel=L"t\,/\,s\,",
#     ylabel=L"\Delta f(t)\,/\,\textrm{Hz}",
#     label=L"\textrm{FDUC}"
# )

# fig6 = Plots.plot(collect(0:0.05:60),
# 	-bench_δf_positor[1:1201, 1];
# 	size  = (300, 300),
# 	xlims = (0, 30),
# 	ylims = (-0.5, 0.2),
# 	# foreground_color_legend = nothing,
# 	tickfontfamily = "Palatino Bold",
# 	legendfontfamily = "Palatino Bold",
# 	xlabel = L"t / s",
# 	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
# 	framestyle = :box,
# 	grid = :true,
# 	foreground_color_grid = :grey,
# 	lw = 3,
# 	xticks = (collect(0:10:60), collect(0:10:60)),
# 	ylabel = L"\Delta f(t) / Hz",
# 	labelfontfamily = "Palatino Bold",
# 	label = "TUC")

fig6 = Plots.plot(collect(0:0.05:60),
	-δf_positor[1:1201, 1];
	size  = (300, 300),
	xlims = (0, 30),
	ylims = (-0.4, 0.1),
	# foreground_color_legend = nothing,
	tickfontfamily = "Palatino Bold",
	legendfontfamily = "Palatino Bold",
	xlabel = L"t / s",
	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
	framestyle = :box,
	grid = :true,
	foreground_color_grid = :grey,
	lw = 3,
	lc = :orange,
	la = 0.75,
	xticks = (collect(0:10:60), collect(0:10:60)),
	ylabel = L"\Delta f(t) / Hz",
	labelfontfamily = "Palatino Bold",
	label = "FDUC")

# fig6 = Plots.plot!(collect(0:0.05:60), -δf_positor[1:1201, 1]; lw = 3.0, label = "FDUC")
fig6 = Plots.plot!(collect(0:0.05:60), -enhance_δf_positor[1:1201, 1]; lc = :blue, la = 0.5, lw = 3.0, label = "CCFDUC")

# filepath = pwd()
# fig5 = Plots.plot(collect(1:NT), -bench_nadir_distribution,
#     xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xlabelfontsize=8, ylabelfontsize=8,
#     marker=:circle,
#     label=L"TUC",
#     size=(300, 300),
#     ylims=(-0.8, -0.2),
# )
# fig5 = Plots.plot!(collect(1:NT), -nadir_distribution, xtickfontsize=6, ytickfontsize=6, legendfontsize=6,)

fig5 = Plots.plot(collect(1:NT), -bench_nadir_distribution;
	marker = :circle,
	label = L"TUC",
	size = (300, 300),
	# ylims = (-0.8, -0.2),
)
fig5 = Plots.plot!(collect(1:NT), -nadir_distribution; xtickfontsize = 6, ytickfontsize = 6, legendfontsize = 6)

Plots.savefig(fig5, filepath * "nadirdistributionINFO.svg")

# # NOTE SFRcurve
# res = zeros(NT, 2)
# δf_positor, δf_actual, δp_actual, δf_samplieddata = simulate(
#     generate_data, particle_filter, 100, 60, 1, 1, units, winds, [1, 1, 0], 1234
# )
# bench_δf_positor, bench_δf_actual, bench_δp_actual, bench_δf_samplieddata = simulate(
#     generate_data, particle_filter, 100, 60, 1, 1, units, winds, [1, 0, 0], 1234
# )

# fig6 = Plots.plot(
#     collect(0:0.05:30),
#     -δf_positor[1:601, 1];
#     size=(300, 300),
#     xlabel=L"t\,/\,s",
#     ylabel=L"\Delta f(t)\,/\,\textrm{Hz}\,",
#     xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xlabelfontsize=8, ylabelfontsize=8,
#     label=L"\textrm{FDUC}"
# )
# fig6 = Plots.plot!(collect(0:0.05:30), -bench_δf_positor[1:601, 1]; label=L"\textrm{TUC}")

# Plots.savefig(fig6, filepath * "SFRcurves.pdf")

M, H, D, T, R, F, K, δp, endtime = formparameter(units, winds, x₀[:, 4], 1)
bench_M, bench_H, bench_D, T, bench_R, bench_F, K, δp, endtime = formparameter(units, winds, bench_x₀[:, 4], 1)
@show formparameter(units, winds, [1, 1, 0], 1)
@show formparameter(units, winds, [1, 1, 0], 1)

δp_add = δf_positor * K / R * 0.50
bench_δp_add = bench_δf_positor * K / bench_R * 0.50
# fig7 = Plots.plot(
#     collect(0:0.05:30),
#     δp_actual[1:601, 1];
#     ylims=(0, 3.0),
#     size=(300, 300),
#     xlabel=L"t\,\,\,[\,s\,]",
#     ylabel=L"\Delta p_{add}(t)\,\,/\,\times e^2 \,\,\textrm{kW}\,\,",
#     label=L"\textrm{FDUC}",
#     xtickfontsize=6, ytickfontsize=6, legendfontsize=6, xlabelfontsize=8, ylabelfontsize=8
# )
# fig7 = Plots.plot!(collect(0:0.05:30), bench_δp_actual[1:601, 1] * 0.95; label=L"\textrm{TUC}")

# fig7 = Plots.plot(collect(0:0.05:60),
# 	bench_δp_actual[1:1201, 1] * 0.95;
# 	xlims = (0, 30),
# 	ylims = (0, 4.0),
# 	size = (300, 300),
# 	xlabel = L"t / s",
# 	ylabel = L"\textrm{Output \,/\, p.u.}",
# 	label = "TUC",
# 	# xtickfontsize = 10, ytickfontsize = 10, legendfontsize = 10, xguidefontsize = 10, yguidefontsize = 10, titlefontsize = 10, linealpha = 0.75, ylabelfontsize = 12, xlabelfontsize = 12,
# 	# foreground_color_legend = nothing,
# 	tickfontfamily = "Palatino Bold",
# 	legendfontfamily = "Palatino Bold",
# 	labelfontfamily = "Palatino Bold",
# 	framestyle = :box,
# 	foreground_color_grid = :grey,
# 	lw = 2,
# 	grid = :true,
# 	xticks = (collect(0:10:60), collect(0:10:60)))
# fig7 = Plots.plot!(collect(0:0.05:60), δp_actual[1:1201, 1] * 0.95; lw = 2.0, label = "FDUC")
# fig7 = Plots.plot!(collect(0:0.05:60), enhance_δp_actual[1:1201, 1] * 0.95; lw = 2.0, label = "CCFDUC")

Sampling_Statue = [1, 1, 0]
sum_ConventionalUnitsPower_bench, sum_WindPower_bench, sum_Bess_bench = calculate_sum_additionalpower(units, winds, Sampling_Statue, stroges, bench_δf_positor)
sum_ConventionalUnitsPower_proposed, sum_WindPower_proposed, sum_Bess_proposed = calculate_sum_additionalpower(units, winds, Sampling_Statue, stroge, δf_positor)
sum_ConventionalUnitsPower_enhanced, sum_WindPower_enhanced, sum_Bess_enhanced = calculate_sum_additionalpower(units, winds, Sampling_Statue, stroges, enhance_δf_positor)

fig7 = draw_SFR_additionalpower(sum_ConventionalUnitsPower_bench, sum_WindPower_bench, sum_Bess_bench,
	sum_ConventionalUnitsPower_proposed, sum_WindPower_proposed, sum_Bess_proposed,
	sum_ConventionalUnitsPower_enhanced, sum_WindPower_enhanced, sum_Bess_enhanced)

fig8 = Plots.plot(fig6, fig7, size = (600, 200), layout = (1, 2))
Plots.savefig(fig6, filepath * "SFRcurves.svg")
Plots.savefig(fig7, filepath * "additionalPower.svg")
Plots.savefig(fig8, filepath * "SFRcurveandadditionaPower.svg")

# NOTE unit online number
plotlyjs()
# ------------------------------- unit nummber ------------------------------- #
NG, NT = size(bench_x₀, 1), size(bench_x₀, 2)
nben_z, npro_z = zeros(NG, NT), zeros(NG, NT)
sort_vector = collect(1:1:NG)
for t in 1:NT
	nben_z[:, t] = bench_x₀[:, t] .* sort_vector[:, 1]
	npro_z[:, t] = x₀[:, t] .* sort_vector[:, 1]
end
ctg = repeat(["Category 1", "Category 2"]; inner = 5)
nam = repeat("G" .* string.(1:5); outer = 2)
nam = repeat("G" .* string.(1:NG); outer = 1)
p1 = Plots.scatter(nben_z';
	size              = (667 * 0.75, 500 * 0.5),
	markeralpha       = 0.00,
	markersize        = 6,
	markercolor       = :orange,
	markershape       = :rect,
	markerstrokecolor = :black,
	markerstrokealpha = 1.0,
	markerstrokewidth = 1.0,
	tickfontfamily    = "Palatino Bold",
	legendfontfamily  = "Palatino Bold",
	labelfontfamily   = "Palatino Bold",
	xticks            = (collect(1:1:NT), collect(1:1:24)),
	yticks            = (collect(1:1:NG), nam),
	ylims             = (0.5, NG + 1),
	legend            = false,
	xlabel            = "t / h",
	ylabel            = "Unit index")
p1 = Plots.scatter!(npro_z';
	# size=(400, 300),
	markersize        = 5,
	markeralpha       = 0.00,
	markercolor       = :blue,
	markershape       = :xcross,
	markerstrokecolor = :blue,
	markerstrokealpha = 1.00,
	markerstrokewidth = 1.00,
	xticks            = (collect(1:1:NT), collect(1:1:24)),
	yticks            = (collect(1:1:NG), nam),
	ylims             = (0.5, NG),
	legend            = false,
	# xlabel="t/h",
	# ylabel="机组编号"
)
Plots.savefig(p1, filepath * "OnlineUnitRes.pdf")

#! draw power balance plots
gr()
preselected_scenarios = 1
p1 = draw_powerbalance(bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻, preselected_scenarios)
p2 = draw_powerbalance(x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻, preselected_scenarios)
p3 = draw_powerbalance(e_x₀,
	e_p₀,
	e_pᵨ,
	e_pᵩ,
	e_seq_sr⁺,
	e_seq_sr⁻,
	e_pss_charge_p⁺,
	e_pss_charge_p⁻,
	e_su_cost,
	e_sd_cost,
	e_prod_cost,
	e_cost_sr⁺,
	e_cost_sr⁻,
	preselected_scenarios)

Plots.savefig(p1, filepath * "powerbalance1.svg")
Plots.savefig(p2, filepath * "powerbalance2.svg")
Plots.savefig(p3, filepath * "powerbalance3.svg")

p4 = Plots.plot(p2, p3, size = (600, 200), legend_column = 2, layout = (1, 2))
Plots.savefig(p4, filepath * "powerbalance2and3.svg")

# #! draw online activated units
bench_x₀, x₀, e_x₀
data = zeros(3, 24)
for t in 1:24
	data[:, t] = [sum(bench_x₀[:, t]), sum(x₀[:, t]), sum(e_x₀[:, t])]
end
xdata = collect(1:24)
p12 = Plots.plot(xdata, data[1, :],
	size        = (450, 150),
	markeralpha = 1.00,
	# markersize        = 6,
	markercolor       = :blue,
	markershape       = :rect,
	markerstrokecolor = :blue,
	markerstrokealpha = 0.5,
	markerstrokewidth = 5.0,
	line              = :steppre,
	framestyle        = :box,
	markersize        = 6,
	legend_column     = -1,
	ma                = 0.75,
	ylabel            = "Number",
	tickfontfamily    = "Palatino Bold",
	legendfontfamily  = "Palatino Bold",
	labelfontfamily   = "Palatino Bold",
	xticks            = (collect(1:1:NT), collect(1:1:24)),
	yticks            = (collect(1:1:NG), collect(1:1:NG)),
	ylims             = (0.5, NG + 1),
	# legend            = false,
	xlabel = L"t / h",
	label  = "TUC",
	lc     = :blue,
	lw     = 2)
Plots.plot!(xdata, data[2, :],
	markeralpha = 1.00,
	# markersize        = 6,
	markercolor       = :orange,
	markershape       = :diamond,
	markerstrokecolor = :orange,
	markerstrokealpha = 0.5,
	markerstrokewidth = 5.0,
	markersize        = 6,
	tickfontfamily    = "Palatino Bold",
	legendfontfamily  = "Palatino Bold",
	labelfontfamily   = "Palatino Bold",
	xticks            = (collect(1:1:NT), collect(1:1:24)),
	# yticks            = (collect(1:1:NG), nam),
	ylims = (0.5, NG + 1),
	# legend            = false,
	label = "FDUC",
	lc    = :orange,
	lw    = 2)
Plots.plot!(xdata, data[3, :],
	markeralpha = 1.00,
	# markersize        = 6,
	markercolor       = :red,
	markershape       = :xcross,
	markerstrokecolor = :red,
	markerstrokealpha = 0.5,
	markerstrokewidth = 10.0,
	ma                = 0.75,
	markersize        = 6,
	tickfontfamily    = "Palatino Bold",
	legendfontfamily  = "Palatino Bold",
	labelfontfamily   = "Palatino Bold",
	xticks            = (collect(1:1:NT), collect(1:1:24)),
	# yticks            = (collect(1:1:NG), nam),
	ylims = (0.5, NG + 1),
	# legend            = false,
	label = "CCFDUC",
	lc    = :red,
	lw    = 2)

Plots.savefig(p12, filepath * "OnlineUnitRes.svg")
