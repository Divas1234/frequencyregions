include("src/automatic_workflow.jl")

# Define a function to generate and plot the inertia-damping functions
function plot_inertia_damping(droop_parameters::AbstractVector)
    if isempty(droop_parameters)
        println("Warning: droop_parameters is empty. No plot will be generated.")
        return
    end

    _plot_inertia_damping(droop_parameters)
end

function _plot_inertia_damping(droop_parameters)
    plots = []
    labels = []
    vertexs = []

    for param in droop_parameters
        p, sub_vertexs = get_inertiatodamping_functions(param)

        # Basic error handling: Check if get_inertiatodamping_functions returned valid data
        if p === nothing || sub_vertexs === nothing
            println("Warning: get_inertiatodamping_functions returned nothing for parameter $param. Skipping this parameter.")
            continue
        end

        push!(plots, p)
        push!(labels, "Droop 1/$(round(1 / param, digits = 3))") # Use string interpolation
        push!(vertexs, sub_vertexs)
    end

    @show vertexs

    # Use the splat operator (...) to pass all plots at once
    Plots.plot(plots...,
        legend = false, size = (1000, 1000),
        xlabel = "Damping", ylabel = "Inertia",
        label = permutedims(labels)) # Use permutedims for correct label orientation

end

# Define droop parameters.  Consider moving this to a separate configuration section if needed.
@show droop_parameters = collect(range(33, 40, length = 20))

# Call plotting function
plot_inertia_damping(droop_parameters)
