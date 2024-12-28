using Pkg
Pkg.activate("D:\\ieee_tpws\\code\\master-3\\.pkg\\")
using DelimitedFiles, Random, Plots, PlotlyJS, PGFPlotsX, Gaston, PlotThemes
gr()
Random.seed!(1234)
include("src/BFLib_consideringFRlimit.jl")
include("src/calcualte_SFRresult.jl")
include("src/draw_SFRcurve.jl")
include("src/CASE1_draw_PDFinfomation.jl")
include("src/draw_SFRsurface.jl")
# include("CASE1_draw_SFRcurve.jl")
theme(:default)

xdata, bench1_ydata1, bench1_ydata2, bench1_ydata3, sampledata1 = Form_SFRcurveData(1, 1)

# large nosie
xdata, bench2_ydata1, bench2_ydata2, bench2_ydata3, sampledata2 = form_SFRcurveData(2, 1)

# case1 with withBESSandWinds
# !large noise
xdata, bench3_ydata1, bench3_ydata2, bench3_ydata3, sampledata3 = form_SFRcurveData(1, 2)
# large nosie
xdata, bench4_ydata1, bench4_ydata2, bench4_ydata3, sampledata4 = form_SFRcurveData(2, 2)

p6, p7 = draw_sfr_surfacedistribution(sampledata1, sampledata2)
p6

# FIXME - draw_sfr_surfacedistribution
Plots.plot(sampledata1[100, :], legeng = false)

using Plots, KernelDensity
num = 2048
kde_xdata, kde_ydata = zeros(size(sampledata1, 1), num), zeros(size(sampledata1, 1), num)
maximum(kde(sampledata1[4, :]).x), minimum(kde(sampledata1[4, :]).x)
maximum(kde(sampledata1[1, :]).density), minimum(kde(sampledata1[1, :]).density)

new_sampledata1 = zeros(size(sampledata1))
maximum(sampledata1(1, :))
for i in 1:1024
	tem₁ = maximum(sampledata1[i, :])
	tem₂ = minimum(sampledata1[i, :])
	new_sampledata1[i, :] .= (sampledata1[i, :] .- tem₂ * ones(1, 100)[1, :]) / (tem₁ - tem₂)
end

for i in 2:1201
	kde_xdata[i, :], kde_ydata[i, :] = kde(new_sampledata1[i, :]).x[:, 1], kde(new_sampledata1[i, :]).density[:, 1]
end
kde_xdata
kde_ydata
xdata = collect(1:1:2048)
ydata = collect(1:1:2048)
p1 = Plots.plot(kde_xdata[2,:], zeros(size(kde_ydata[2,:])), kde_ydata[2,:],legend = false, ls = :dash, lw = 0.5, color = :black, alpha = 0.5)
for i in 3:1201
	p1 = Plots.plot!(kde_xdata[i,:], zeros(size(kde_ydata[i,:])) .+ i, kde_ydata[i,:])
end
p1

# Plots.plot(kde_xdata[4,:], kde_ydata[4,:], legend = false)
# Plots.plot!(kde_xdata[5,:], kde_ydata[5,:], legend = false)
# Plots.plot!(kde_xdata[6,:], kde_ydata[6,:], legend = false)
# Plots.plot!(kde_xdata[7,:], kde_ydata[7,:], legend = false)
# Plots.plot!(kde_xdata[8,:], kde_ydata[8,:], legend = false)
# Plots.plot!(kde_xdata[9,:], kde_ydata[9,:], legend = false)
