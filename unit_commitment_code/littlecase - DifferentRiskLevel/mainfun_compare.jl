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
include("src/enhance_FCUCuccommitmentmodel.jl")
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad = readxlssheet()
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData)

winds, NW = genscenario(WindsFreqParam, 1)

# boundrycondition(NB::Int64, NL::Int64, NG::Int64, NT::Int64, ND::Int64, units::unit, loads::load, lines::transmissionline, winds::wind, stroges::stroge)

#! test
# println("prepare...")
# flag_method_type = 1
# NN = 20 # sampled scenarios for chance constraints
# μ, σ = 0, 0.5e-3
# fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability = generatefreq_fittingparameters(units, winds, NG, NW, NN, flag_method_type, μ, σ)

# println(DataFrame(abs.(whitenoise_parameter)',:auto))
# println(DataFrame(whitenoise_parameter_probability',:auto))

#* calculating different value along with different residual settings.
residual_scenarios_num = 5
for r in 4:residual_scenarios_num
	enhance_FCUC_scucmodel(NT, NB, NG, ND, NC, units, loads, winds, lines, config_param, r)
	savebalance_result(e_p₀, e_pᵨ, e_pᵩ, e_pss_charge_p⁺, e_pss_charge_p⁻, 3)
end
