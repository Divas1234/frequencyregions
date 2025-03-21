using Pkg
Pkg.activate(".Pkg/")
using Plots, PlotThemes
gr()
theme(:wong2)

include("boundary.jl")
include("inertia_response.jl")
include("primary_frequencyresponse.jl")
include("analytical_systemfrequencyresponse.jl")
include("inertia_damping_regressionrelations.jl")
include("visulazations.jl")
