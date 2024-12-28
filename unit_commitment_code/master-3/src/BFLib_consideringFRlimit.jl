#! flag = 1: reheated thermal units
#! flag = 2: reheated thermal units & hydro units
#! flag = 3: reheated thermal units & converter-interfaced units
#! Important change the inertia constant of system frequency parameters when simulating the case 2 and case 3

const whitenoise_parameter = 1e-3
const δt = 0.05
using Distributions
# JuliaFormatter

function formparameter(temflag)
    D, M, H, Tᵣ, Fₕ, R, K = 1.2, 4.96 * 2, 4.96, 10.8, 0.24, 1 / 20.8, 1.00
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = M, H, D, Tᵣ, R, Fₕ, K, 6.1, 60
    # # ------------------log-----------------------
    # # Mw, Hw, Dw, Rw, Re = 2.0, 1.0, 0.3, 1/0.4, 1/0.4
    if temflag == 1
        Mw, Hw, Dw, Rw, Re = 2.0, 1.0, 0.3, 1 / 0.5, 1 / 0.4
        Mg, Hg, Dg = Mg + Mw, Hg + Hw, Dg + Dw + 1 / 0.5 + 1 / 0.4
    end
    # # --------------------------------------------
    return Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime
end

function trans_fun_0(δfₜ, δp_add, δt, i, flag, temflag)
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp₀, endtime = formparameter(temflag)
    # current mismatch power
    temp_δpₜ = δp₀ - Dg * δfₜ[1] - δp_add
    # current ROCOF
    grad_δfₜ = temp_δpₜ / (2 * Hg)
    # current frequency change
    temp_δfₜ = δfₜ[1] + grad_δfₜ * δt
    return temp_δfₜ
end

#process equation
function trans_fun_1(trans_fun_0, 𝚫f_pre, δp_add, δt, k, flag, Q, temflag)
    Q = 1
    tem = trans_fun_0(𝚫f_pre, δp_add, δt, k, flag, temflag)
    if flag == 1
        tem = tem[1] .+ rand(Normal(0, Q), length(𝚫f_pre)) * whitenoise_parameter * 1.0
    end
    if flag == 2
        tem = tem[1] .+ rand(Normal(0, Q), length(𝚫f_pre)) * whitenoise_parameter * (2^(flag - 1))
    end
    if flag >= 2
        tem = tem[1] .+ rand(Normal(0, Q), length(𝚫f_pre)) * whitenoise_parameter * (2 * (flag - 1))
    end
    return tem
end

# ANCHOR
# flag: =1 only thermal unit considered
# flag: =2 both converter-based generators considered
function obs_fun_0(δfₜ_cur, i, flag, temflag)
    # if flag == Int32(1)
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp₀, endtime = formparameter(temflag)
    tem₁, tem₂, tem₃ = 0, 0, 0
    α, β = Fg * (Kg / Rg) + Mg / Tg, (Dg + 1 / Rg) / Tg
    tem₁ = sum(β * δfₜ_cur[j, 1] * δt for j in 1:i)
    tem₂ = α * δfₜ_cur[i, 1]
    tem₃ = (1 / Tg) * δp₀ * (i * δt)
    δpₜ_add = tem₁ + tem₂ - tem₃
    # elseif flag == Int32(2)
    #     Mg, Hg, Dg, Tg, Rg, Fg, Kg, tem, endtime = formparameter()
    #     β = (Fg + (1 - Fg) / Tg) * exp(-1.0 / Tg * i * δt)
    #     δpgₜ_add = (Kg / Rg) * β * δfₜ_cur * (-1.0)
    #     # define hydro unit frequency control
    #     Tw, Kw, Rw = 2.00, 1.00, 1.00 / 30
    #     # γ = 3.0 / (0.50 * Tw) * exp(-2.0 / Tw * (i - 1) * δt) + 1
    #     γ =
    #         (6.0 / (Tw - 2 * 8)) * exp(-2.0 / Tw * (i) * δt) +
    #         (-2.0 / 8.0 + 6.0 / (2 * 8.0 - Tw)) * exp(-1.0 / 8 * (i) * δt) * 2
    #     if γ < 0
    #         γ = 0
    #     end
    #     δpwₜ_add = (Kw / Rw) * γ * δfₜ_cur * (1.0)
    #     δpₜ_add = δpgₜ_add + δpwₜ_add
    # end
    return δpₜ_add
end

# ANCHOR
# symflag:=0 frequency limit not considered
# symflag:=1 frequency limit considered
#observation equation
function obs_fun_1(obs_fun_0, δfₜ_cur, i, flag, symflag, R, temflag)
    R = 1
    tem = obs_fun_0(δfₜ_cur, i, flag, temflag)
    if flag == 1
        tem = tem + rand(Normal(0, R), length(δfₜ_cur))[1] * whitenoise_parameter * 0.10
    end
    if flag == 2
        tem = tem + rand(Normal(0, R), length(δfₜ_cur))[1] * whitenoise_parameter * (2^(flag - 1))
    end
    return tem
end

function frequencydynamic_ASFR(temflag)
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter(temflag)
    D, M, H, Tᵣ, Fₕ, R, K = Dg, Mg, Hg, Tg, Fg, Rg, Kg
    R = Rg / Kg
    δp = δp * 1.0
    wₙ = sqrt((D + K / R) / (2 * H * Tᵣ))
    ζ = (2 * H + (Fₕ * (K / R) + D) * Tᵣ) / (2 * sqrt(2 * H * Tᵣ) * sqrt(D + K / R))
    # ζ = (D * R * Tᵣ + 2 * H * R + Fₕ * Tᵣ) / 2 / (D * R + 1) * wₙ
    wᵣ = wₙ * sqrt(1 - ζ^2)
    ψ = asin(sqrt(1 - ζ^2))

    xdata = collect(0:δt:endtime)
    ydata = zeros(size(xdata, 1), 1)
    f_base = 50

    for i in 1:size(xdata, 1)
        t = xdata[i, 1]
        # δf = R * δp / (D * R + 1)
        # δf = δf * (1 + α * exp(-1.0 * ζ * wₙ * t) * sin(wᵣ * 1.0 * t + ψ))
        δf = δp / (2 * H * Tᵣ * (wₙ^2))
        δf =
            δf +
            δp / (2 * Hg * wᵣ) * exp(-ζ * wₙ * t) * (sin(wᵣ * t) - 1 / (wₙ * Tᵣ) * sin(wᵣ * t + ψ))
        ydata[i, 1] = f_base - δf
    end
    ydata[1:2, 1] = ydata[1:2, 1] .* 1.00
    ydata[:, 1] = ydata[:, 1] .+ 0.0
    different_ASFR = zeros(size(xdata, 1), 1)
    increment_Padd = zeros(size(xdata, 1), 1)
    for i in 1:Int64(size(xdata, 1) - 1)
        different_ASFR[i, 1] = (ydata[i+1, 1] - ydata[i, 1]) / δt
        str = (Fg + (1 - Fg) / Tg) * exp(-1.0 / Tg * i * δt)
        increment_Padd[i, 1] = (Kg / Rg) * str * (f_base - ydata[i, 1])
    end
    return ydata, different_ASFR, increment_Padd
end

#initial pdf
function initialize(m, sd=1)
    # return zeros(m, 1)
    # tem = rand(Normal(0, sd), m)
    # tem1 = zeros(size(tem,1), size(tem,2))
    # return tem1

    # version 2
    # return rand(Normal(0, sd), m) * 0 .+ 2
    # version 3
    return rand(Normal(0, sd), m) * whitenoise_parameter
    # return 2
end

function generate_data(initialize, trans_fun_1, obs_fun_1, tt, flag, symflag, temflag)
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter(temflag)
    δf, δp_add = fill(0.0, tt), fill(0.0, tt)
    for i in 2:tt
        δfₜ_cur = trans_fun_1(trans_fun_0, δf[i-1, 1], δp_add[i-1, 1], δt, i, flag, 1, temflag)
        δf[i] = δfₜ_cur[1]
        δpₜ_add = obs_fun_1(obs_fun_0, δf[1:i, 1], i, flag, symflag, 1, temflag)
        δp_add[i] = δpₜ_add[1]
    end
    return [δf, δp_add]
end

# function conditional_likelihoods(obs_fun_0, y, x, t, flag, R = 1)
#     # h = zeros(size(x,1), 1)
#     # for i in 1:size(x,1)
#     #     h[i,1] = obs_fun_0(x[i])
#     # end
#     h = obs_fun_0.(x, t, flag)
#     likelihoods = pdf.(Normal(0, R), y .- h)
#     return likelihoods
# end

function reconditional_likelihoods(obs_fun_0, δp_measured, δf_inference, t, flag, R, temflag)
    R = 1
    sample_Number = size(δf_inference, 2)
    δp_prositor = zeros(sample_Number, 1)
    for i in 1:sample_Number
        δp_prositor[i, 1] = obs_fun_0(δf_inference[1:t, i], t, flag, temflag)
    end
    likelihoods = pdf.(Normal(0, R), δp_measured .- δp_prositor)
    return likelihoods
end

function multi_trans_fun_1(trans_fun_0, Δf_pre, Δp_add, δt, t, flag, symflag, temflag)
    tem = zeros(size(Δf_pre, 1), 1)
    δp_add = convert(Float64, Δp_add[1])
    for i in 1:size(Δf_pre, 1)
        δf_pre = convert(Float64, Δf_pre[i])
        tem[i, 1] = trans_fun_1(trans_fun_0, δf_pre, δp_add, δt, t, flag, symflag, temflag)[1]
    end
    return tem
end

function particle_filter(
    data, initialize, multi_trans_fun_1, reconditional_likelihoods, N, tt, flag, symflag, temflag,
)
    x_true, y_true = data[1], data[2]
    𝚫f_post, 𝚫p_post = zeros(tt, N), y_true
    Mg, Hg, Dg, Tg, Rg, Fg, Kg, δp, endtime = formparameter(temflag)
    δp = δp * (-1.0)
    for t in 2:tt
        # Prediction: sample from p(x_k|x_k-1)
        δfₜ_pre = multi_trans_fun_1(
            trans_fun_0, 𝚫f_post[t-1, :], 𝚫p_post[t-1, 1], δt, t - 1, flag, 1, temflag,
        )
        𝚫f_post[t, :] = δfₜ_pre
        # Update: compute weights p(y_k|x_k)
        likelihood = reconditional_likelihoods(
            obs_fun_0, y_true[t], 𝚫f_post[1:t, :], t, flag, 1, temflag,
        )
        if likelihood == fill(0.0, N)
            δfₜ_post = δfₜ_pre
        else
            likelihood = likelihood ./ sum(likelihood)
            # Resampling: Draw N new particles
            δfₜ_post = wsample(δfₜ_pre[:, 1], likelihood[:, 1], size(δfₜ_pre, 1))
        end
        𝚫f_post[t, :] = δfₜ_post
    end
    sample_SFRdata = zeros(tt, 1)
    for i in 1:tt
        sample_SFRdata[i, 1] = sum(𝚫f_post[i, :]) / N
    end
    return sample_SFRdata, 𝚫f_post
end

function simulate(
    generate_data, particle_filter, sample_Num, horizon, flag, symflag, temflag, seed=rand(),
)
    rand(seed)
    N = size(collect(0:δt:horizon), 1)
    data = generate_data(initialize, trans_fun_1, obs_fun_1, N, flag, symflag, temflag)
    𝚫f_particle_set, 𝚫f_post = particle_filter(
        data,
        initialize,
        trans_fun_1,
        reconditional_likelihoods,
        sample_Num,
        N,
        flag,
        symflag,
        temflag,
    )
    # println([size(𝚫f_post,1), size(𝚫f_post,2)])
    # x_expected = mean.(𝚫f_post)
    # return x_expected, data[1], 𝚫f_particle_set
    return 𝚫f_particle_set, data[1], 𝚫f_post
end
