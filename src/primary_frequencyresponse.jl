# # FR stage
# """
#     inertia_bindings(damping::Vector{Float64}, factorial_coefficient::Float64, time_content::Float64, droop::Float64) -> Matrix{Float64}

# Calculate the upper and lower inertia bounds for a given set of damping values, factorial coefficient, time content, and droop.

# # Arguments
# - `damping::Vector{Float64}`: A vector of damping values.
# - `factorial_coefficient::Float64`: The factorial coefficient.
# - `time_content::Float64`: The time content value.
# - `droop::Float64`: The droop value.

# # Returns
# - `Matrix{Float64}`: A matrix with two columns containing the upper and lower bounds for each damping value.
# """
function inertia_bindings(damping, factorial_coefficient, time_content, droop)
    tem = zeros(length(damping), 2)
    for i in eachindex(damping)
        upper_bound_1, lower_bound_1 = inertia_damping_relations(
            damping[i], factorial_coefficient, time_content, droop)
        tem[i, 1] = upper_bound_1
        tem[i, 2] = lower_bound_1
    end
    @assert tem[:, 1] > tem[:, 2]
    return tem
end

# """
#     inertia_damping_relations(damping::Float64, factorial_coefficient::Float64, time_content::Float64, droop::Float64) -> Tuple{Float64, Float64}

# Calculate the upper and lower bounds for inertia given damping, factorial coefficient, time content, and droop.

# # Arguments
# - `damping::Float64`: The damping value.
# - `factorial_coefficient::Float64`: The factorial coefficient.
# - `time_content::Float64`: The time content value.
# - `droop::Float64`: The droop value.

# # Returns
# - `Tuple{Float64, Float64}`: A tuple containing the upper and lower bounds.
# """
function inertia_damping_relations(damping::Float64, factorial_coefficient::Float64, time_content::Float64, droop::Float64)
    tem1 = (damping - factorial_coefficient + 2 * droop)
    tem2 = tem1^2 - (damping + factorial_coefficient)^2

    @assert tem2 >= 0
    @assert droop > factorial_coefficient

    lower_bound_1 = time_content * (tem1 - sqrt(tem2)) / 2
    upper_bound_1 = time_content * (tem1 + sqrt(tem2)) / 2

    println("damping = ", damping, ", factorial_coefficient = ", factorial_coefficient, ", droop = ", droop)
    println("tem1 = ", tem1, ", tem2 = ", tem2)
    println("upper_bound_1 = ", upper_bound_1, ", lower_bound_1 = ", lower_bound_1)

    return upper_bound_1, lower_bound_1
end

