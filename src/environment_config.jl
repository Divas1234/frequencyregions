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
include("converter_config.jl")

# Constants (could also be in environment_config.jl)
const DAMPING_RANGE = 2:0.25:15
const MIN_DAMPING = minimum(DAMPING_RANGE)
const MAX_DAMPING = maximum(DAMPING_RANGE)

# Constants for the formulas
const PERCENTAGE_BASE = 100
const FREQUENCY_BASE = 50
