using Pkg
Pkg.activate("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/.pkg/")
using DelimitedFiles, Random, Plots, PlotlyJS, PGFPlotsX, Gaston, PlotThemes

# plotlyjs()
# gaston()
# pgfplotsx()
# pythonplot()
gr()
Random.seed!(1234)
include("src/BFLib_consideringFRlimit.jl")
include("src/calcualte_SFRresult.jl")
include("src/draw_SFRcurve.jl")
include("src/CASE1_draw_PDFinfomation.jl")
include("src/draw_SFRsurface.jl")
# include("CASE1_draw_SFRcurve.jl")
theme(:default)
# theme(:vibrant)
# case1 without withBESSandWinds
# !little noise

xdata, bench1_ydata1, bench1_ydata2, bench1_ydata3, sampledata1 = form_SFRcurveData(1, 1)
# large nosie
xdata, bench2_ydata1, bench2_ydata2, bench2_ydata3, sampledata2 = form_SFRcurveData(2, 1)

# case1 with withBESSandWinds
# !large noise
xdata, bench3_ydata1, bench3_ydata2, bench3_ydata3, sampledata3 = form_SFRcurveData(1, 2)
# large nosie
xdata, bench4_ydata1, bench4_ydata2, bench4_ydata3, sampledata4 = form_SFRcurveData(2, 2)

# !draw curve about different residuals and distributions
p1 = draw_sfr_curve3(xdata, bench1_ydata2, bench1_ydata3, bench3_ydata2, bench3_ydata3, sampledata1, sampledata3)
p2 = draw_sfr_curve3(xdata, bench2_ydata2, bench2_ydata3, bench4_ydata2, bench4_ydata3, sampledata2, sampledata4)

fig1 = Plots.plot(p1, p2; size = (600, 300), layout = (1, 2))
figpath = "/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/out/"
Plots.savefig(fig1, figpath * "new_SFRcurves.svg")
Plots.savefig(p1, figpath * "littlenoise_SFRcurves.svg")
Plots.savefig(p2, figpath * "bignoise_SFRcurves.svg")

p4 = draw_case1_SFRdistribution(sampledata1, sampledata2)
p5 = draw_case1_boxplot(sampledata1, sampledata2)
fig2 = Plots.plot(p5, p4; size = (600, 300), layout = (1, 2))

Plots.savefig(p4, figpath * "pdf.svg")
Plots.savefig(p5, figpath * "boxplot.svg")
Plots.savefig(fig2, figpath * "SFRPDFinformations.svg")

p6, p7 = draw_sfr_surfacedistribution(sampledata1, sampledata2)
Plots.savefig(p6, figpath * "surface1.svg")
Plots.savefig(p7, figpath * "surface2.svg")

theme(:bright)
gr()
fig2 = Plots.plot(p6, p7; size = (600, 200), layout = (1, 2))
Plots.savefig(fig2, figpath * "surface1and2.pdf")

# !SECTION save data
open("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/out/result.txt", "w") do io
	writedlm(io, [" "])
	writedlm(io, sampledata1, '\t')
end
open("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/out/result1.txt", "w") do io
	writedlm(io, [" "])
	writedlm(io, sampledata2, '\t')
end

# !draw trend curve along with different residual settings.
# ANCHOR xesix, asfr data, bf-sfr data, sim data, samplied data
gr()
N = 10
ydata = zeros(1201, N)
sampled_filters = zeros(1201, 100, N)
for i in 1:N
	ydata[:, i], ~, sampled_filters[:, :, i] = simulate(generate_data, particle_filter, 100, 60, i, 1, 1, 1234)
end
Plots.plot(-ydata[:, 1:3])
time_to_nadir = Int64(round(7.5 / δt))
new_ydata = zeros(100, N)
for i in 1:N
	new_ydata[:, i] = sampled_filters[time_to_nadir, :, i]
end
new_ydata
using DataFrames
df1 = DataFrame(new_ydata, :auto)
println(df1)
open("/Users/yuanyiping/Documents/GitHub/unit_commitment_code/master-3/out/result2_forCloudRainVis.txt", "w") do io
	writedlm(io, [" "])
	writedlm(io, new_ydata, '\t')
end
