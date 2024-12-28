function generatefreq_fittingparameters(units, winds, NG, NW, NN, flag_method_type, residual_estimator,μ, σ)

    # flag_method_type = 1
    # * ANCHOR: here whitenoise_parameter denotes the preselected fluctuating value
	whitenoise_parameter = rand(Normal(μ, σ), NN)
	whitenoise_parameter_probability = cdf(Normal(μ, σ), whitenoise_parameter)
    fittingparameter_vector = zeros(NN, 4)
    for n in 1:NN
        println([residual_estimator, n]')
        fittingparameter_vector[n, :] = creatfrequencyfittingfunction(units, winds, NG, NW, flag_method_type, whitenoise_parameter[n])
    end
    return fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability
end