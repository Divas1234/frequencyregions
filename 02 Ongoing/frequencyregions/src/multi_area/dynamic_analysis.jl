"""
	multi_area/dynamic_analysis.jl

English: Provides a physics-based 2-area frequency response model with primary governor control
and a nonlinear tie-line capacity limit. Solves the coupled differential equations
using Runge-Kutta 4th order (RK4) to find precise frequency nadir and ROCOF values.
Chinese: 提供一个基于物理的、包含一次调频控制和非线性联络线功率传输容量极限的双区域频率响应动态模型。
使用四阶龙格库塔法 (RK4) 求解耦合微分方程组，以精确计算系统频率最低点 (Nadir) 以及频率变化率 (ROCOF)。
"""

"""
	simulate_multiarea_frequency_response(...)

English: Simulates the dynamic frequency response of a 2-area power system connected via a tie-line.
Chinese: 模拟通过联络线互联的双区域电力系统的动态频率响应过程。

# Arguments (参数)
- `H1`, `D1`, `R1`, `Tg1`, `Km1`: Parameters of Area 1 (Inertia, Damping, Droop, Gov constant, Turbine fraction)
								区域 1 的参数（等效惯性、阻尼系数、下垂系数、调速器时间常数、原动机占比系数）
- `DP1`: Disturbance in Area 1 (p.u. or % base) (区域 1 的有功功率扰动故障量标么值)
- `H2`, `D2`, `R2`, `Tg2`, `Km2`: Parameters of Area 2 (区域 2 的发电机与控制器运行参数)
- `DP2`: Disturbance in Area 2 (typically 0.0 for healthy area) (区域 2 的扰动故障量，健全区域通常为 0.0)
- `T12`: Tie-line synchronizing coefficient (联络线整步功率系数)
- `C12`: Tie-line capacity limit (联络线跨区电网电能传输容量极限)

# Returns (返回)
- `nadir1`, `nadir2`: Frequency nadir (maximum deviation in Hz) in Area 1 and Area 2
					  区域 1 和区域 2 的频率最大下降最低点偏差 [Hz] (正值表示偏差绝对值)
- `rocof1`, `rocof2`: Maximum Rate of Change of Frequency (Hz/s) in Area 1 and Area 2
					  区域 1 和区域 2 的频率最大变化率绝对值 [Hz/s]
"""
function simulate_multiarea_frequency_response(
	H1::Float64, D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
	H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
	T12::Float64, C12::Float64;
	t_max::Float64 = 10.0, dt::Float64 = 0.005,
)
	# State variables (状态变量):
	# df1  : Frequency deviation in Area 1 (Hz) / 区域 1 频率偏差 (Hz)
	# xg1  : Governor state in Area 1 / 区域 1 调速器内部门阀开度状态
	# df2  : Frequency deviation in Area 2 (Hz) / 区域 2 频率偏差 (Hz)
	# xg2  : Governor state in Area 2 / 区域 2 调速器内部开度状态
	# P_tie: Power flow from Area 2 to Area 1 (%), constrained by -C12 and C12
	#        从区域 2 流向区域 1 的联络线交换功率标么值，受限于传输极限 [-C12, C12]
	df1 = 0.0
	xg1 = 0.0
	df2 = 0.0
	xg2 = 0.0
	P_tie = 0.0

	n_steps = round(Int, t_max / dt)

	min_df1 = 0.0
	min_df2 = 0.0
	max_rocof1 = 0.0
	max_rocof2 = 0.0

	for step in 1:n_steps
		# Helper function to compute derivatives for RK4
		# RK4 导数计算辅助闭包函数
		function get_derivatives(df1_val, xg1_val, df2_val, xg2_val, P_tie_val)
			# Mechanical power deviations (机械功率偏差计算)
			Pm1 = - Km1 * R1 * df1_val + (1.0 - Km1) * xg1_val
			Pm2 = - Km2 * R2 * df2_val + (1.0 - Km2) * xg2_val

			# Frequency dynamics (swing equations / 转子运动方程)
			ddf1 = (Pm1 - D1 * df1_val - DP1 + P_tie_val) / H1
			dxg1 = - (df1_val * R1 / Tg1) - (xg1_val / Tg1)

			ddf2 = (Pm2 - D2 * df2_val - DP2 - P_tie_val) / H2
			dxg2 = - (df2_val * R2 / Tg2) - (xg2_val / Tg2)

			# Tie-line dynamics: P_tie flows from 2 to 1, driven by (df2 - df1)
			# We scale the synchronizing coefficient by 2 * pi (without double f_base scaling)
			# 联络线功率动态：由于频率差引起的同步功率交换，乘上系统同步角频率系数
			dP_tie = 2.0 * pi * T12 * (df2_val - df1_val)

			# Nonlinear clamping: if saturated, rate is zero in the direction of saturation
			# 非线性饱和钳位控制：若交换功率已达容量上限且趋势仍然增加，则导数置零
			if P_tie_val >= C12 && dP_tie > 0.0
				dP_tie = 0.0
			elseif P_tie_val <= -C12 && dP_tie < 0.0
				dP_tie = 0.0
			end

			return ddf1, dxg1, ddf2, dxg2, dP_tie
		end

		# Track current step's ROCOF (记录当前步的频率变化率)
		Pm1_curr = - Km1 * R1 * df1 + (1.0 - Km1) * xg1
		Pm2_curr = - Km2 * R2 * df2 + (1.0 - Km2) * xg2

		rocof1_val = (Pm1_curr - D1 * df1 - DP1 + P_tie) / H1
		rocof2_val = (Pm2_curr - D2 * df2 - DP2 - P_tie) / H2

		max_rocof1 = max(max_rocof1, abs(rocof1_val))
		max_rocof2 = max(max_rocof2, abs(rocof2_val))

		# RK4 integrations (四阶龙格库塔数值积分步骤)
		k1_df1, k1_xg1, k1_df2, k1_xg2, k1_Ptie = get_derivatives(df1, xg1, df2, xg2, P_tie)

		k2_df1, k2_xg1, k2_df2, k2_xg2, k2_Ptie = get_derivatives(
			df1 + 0.5*dt*k1_df1, xg1 + 0.5*dt*k1_xg1,
			df2 + 0.5*dt*k1_df2, xg2 + 0.5*dt*k1_xg2,
			clamp(P_tie + 0.5*dt*k1_Ptie, -C12, C12),
		)

		k3_df1, k3_xg1, k3_df2, k3_xg2, k3_Ptie = get_derivatives(
			df1 + 0.5*dt*k2_df1, xg1 + 0.5*dt*k2_xg1,
			df2 + 0.5*dt*k2_df2, xg2 + 0.5*dt*k2_xg2,
			clamp(P_tie + 0.5*dt*k2_Ptie, -C12, C12),
		)

		k4_df1, k4_xg1, k4_df2, k4_xg2, k4_Ptie = get_derivatives(
			df1 + dt*k3_df1, xg1 + dt*k3_xg1,
			df2 + dt*k3_df2, xg2 + dt*k3_xg2,
			clamp(P_tie + dt*k3_Ptie, -C12, C12),
		)

		df1 += (dt / 6.0) * (k1_df1 + 2.0*k2_df1 + 2.0*k3_df1 + k4_df1)
		xg1 += (dt / 6.0) * (k1_xg1 + 2.0*k2_xg1 + 2.0*k3_xg1 + k4_xg1)
		df2 += (dt / 6.0) * (k1_df2 + 2.0*k2_df2 + 2.0*k3_df2 + k4_df2)
		xg2 += (dt / 6.0) * (k1_xg2 + 2.0*k2_xg2 + 2.0*k3_xg2 + k4_xg2)
		P_tie = clamp(P_tie + (dt / 6.0) * (k1_Ptie + 2.0*k2_Ptie + 2.0*k3_Ptie + k4_Ptie), -C12, C12)

		# Track the absolute minimum frequency deviations (即 nadir 偏差极限点)
		min_df1 = min(min_df1, df1)
		min_df2 = min(min_df2, df2)
	end

	return abs(min_df1), abs(min_df2), max_rocof1, max_rocof2
end

"""
	find_critical_inertia_nadir(...) -> Float64

English: Performs a bisection search to find the minimum required inertia H1 that satisfies
the frequency nadir deviation threshold in Area 1 while ensuring Area 2 also meets its threshold.
Chinese: 采用二分搜索算法寻找满足区域 1 频率最低点阈值，同时确保健全区域（区域 2）也满足安全极限的临界惯性 H1。

# Arguments (参数)
- `nadir_threshold1`: Maximum allowed deviation for Area 1 (区域 1 的最大允许频率最低点偏差)
- `nadir_threshold2`: Maximum allowed deviation for Area 2 (区域 2 的最大允许频率最低点偏差)
- `H_min_search`: Lower bound of bisection search (二分搜索下限)
- `H_max_search`: Upper bound of bisection search (二分搜索上限)

# Returns (返回)
- `Float64`: The critical required inertia for Area 1 (区域 1 的临界必要惯性标么值)
"""
function find_critical_inertia_nadir(
	D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
	H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
	T12::Float64, C12::Float64, nadir_threshold1::Float64, nadir_threshold2::Float64;
	H_min_search::Float64 = 0.05, H_max_search::Float64 = 100.0, tol::Float64 = 1e-3,
)
	# Convert thresholds from Hz to p.u. (50 Hz base)
	th1 = nadir_threshold1 / 50.0
	th2 = nadir_threshold2 / 50.0

	# Non-finite trajectories are violations.  Otherwise a numerically invalid
	# low-inertia point can be mistaken for a safe point by the search.
	satisfies_nadir = function(H1)
		nadir1, nadir2, _, _ = simulate_multiarea_frequency_response(
			H1, D1, R1, Tg1, Km1, DP1,
			H2, D2, R2, Tg2, Km2, DP2,
			T12, C12,
		)
		return isfinite(nadir1) && isfinite(nadir2) && nadir1 <= th1 && nadir2 <= th2
	end

	# Check boundary conditions first (先进行边界安全检测)
	if !satisfies_nadir(H_max_search)
		# Even with max search inertia, nadir is violated in either Area 1 or Area 2
		# 即使使用了搜索的最大惯性，仍然存在区域不满足频率约束，说明解越界，返回最大值
		return H_max_search
	end

	low = H_min_search
	high = H_max_search

	# The response is not guaranteed to be monotone over the entire numerical
	# interval.  When the lower endpoint is safe, scan for the last
	# unsafe-to-safe transition so a small low-inertia island is not selected.
	if satisfies_nadir(H_min_search)
		scan_points = collect(range(H_min_search, H_max_search; length = 33))
		scan_safe = [satisfies_nadir(H) for H in scan_points]
		transition = findlast(i -> !scan_safe[i] && scan_safe[i + 1], 1:(length(scan_safe) - 1))
		if isnothing(transition)
			return H_min_search
		end
		low = scan_points[transition]
		high = scan_points[transition + 1]
	end

	# Perform Bisection (执行二分逼近搜索)
	while (high - low) > tol
		mid = 0.5 * (low + high)
		if !satisfies_nadir(mid)
			# Violation in either area: needs more inertia support in Area 1
			# 任何一个区域超标，说明当前惯性不足，抬高下限
			low = mid
		else
			# Both areas are safe: try decreasing inertia to find critical boundary
			# 两个区域均安全，可以进一步降低惯性，降低上限
			high = mid
		end
	end

	return high
end


"""
    simulate_multiarea_frequency_unclamped(...) -> Float64

English: Simulates the dynamic frequency response of a 2-area system without tie-line capacity clamping, and returns the peak tie-line power flow.
Chinese: 在没有联络线容量上限钳位的情况下，模拟双区域互联系统的动态频率响应过程，并返回联络线功率的最大峰值。
"""
function simulate_multiarea_frequency_unclamped(
	H1::Float64, D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
	H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
	T12::Float64;
	t_max::Float64 = 10.0, dt::Float64 = 0.005,
)
	df1 = 0.0
	xg1 = 0.0
	df2 = 0.0
	xg2 = 0.0
	P_tie = 0.0

	n_steps = round(Int, t_max / dt)
	max_Ptie = 0.0

	for step in 1:n_steps
		function get_derivatives(df1_val, xg1_val, df2_val, xg2_val, P_tie_val)
			Pm1 = - Km1 * R1 * df1_val + (1.0 - Km1) * xg1_val
			Pm2 = - Km2 * R2 * df2_val + (1.0 - Km2) * xg2_val

			ddf1 = (Pm1 - D1 * df1_val - DP1 + P_tie_val) / H1
			dxg1 = - (df1_val * R1 / Tg1) - (xg1_val / Tg1)

			ddf2 = (Pm2 - D2 * df2_val - DP2 - P_tie_val) / H2
			dxg2 = - (df2_val * R2 / Tg2) - (xg2_val / Tg2)

			dP_tie = 2.0 * pi * T12 * (df2_val - df1_val)

			return ddf1, dxg1, ddf2, dxg2, dP_tie
		end

		# RK4 integration
		k1_df1, k1_xg1, k1_df2, k1_xg2, k1_Ptie = get_derivatives(df1, xg1, df2, xg2, P_tie)

		k2_df1, k2_xg1, k2_df2, k2_xg2, k2_Ptie = get_derivatives(
			df1 + 0.5*dt*k1_df1, xg1 + 0.5*dt*k1_xg1,
			df2 + 0.5*dt*k1_df2, xg2 + 0.5*dt*k1_xg2,
			P_tie + 0.5*dt*k1_Ptie,
		)

		k3_df1, k3_xg1, k3_df2, k3_xg2, k3_Ptie = get_derivatives(
			df1 + 0.5*dt*k2_df1, xg1 + 0.5*dt*k2_xg1,
			df2 + 0.5*dt*k2_df2, xg2 + 0.5*dt*k2_xg2,
			P_tie + 0.5*dt*k2_Ptie,
		)

		k4_df1, k4_xg1, k4_df2, k4_xg2, k4_Ptie = get_derivatives(
			df1 + dt*k3_df1, xg1 + dt*k3_xg1,
			df2 + dt*k3_df2, xg2 + dt*k3_xg2,
			P_tie + dt*k3_Ptie,
		)

		df1 += (dt / 6.0) * (k1_df1 + 2.0*k2_df1 + 2.0*k3_df1 + k4_df1)
		xg1 += (dt / 6.0) * (k1_xg1 + 2.0*k2_xg1 + 2.0*k3_xg1 + k4_xg1)
		df2 += (dt / 6.0) * (k1_df2 + 2.0*k2_df2 + 2.0*k3_df2 + k4_df2)
		xg2 += (dt / 6.0) * (k1_xg2 + 2.0*k2_xg2 + 2.0*k3_xg2 + k4_xg2)
		P_tie += (dt / 6.0) * (k1_Ptie + 2.0*k2_Ptie + 2.0*k3_Ptie + k4_Ptie)

		max_Ptie = max(max_Ptie, abs(P_tie))
	end

	return max_Ptie
end


"""
    find_critical_inertia_tieline(...) -> Float64

English: Performs a bisection search to find the maximum permitted inertia H1 that satisfies the tie-line capacity limit C12 in unclamped dynamic simulation.
Chinese: 采用二分搜索算法寻找在无钳位动态模拟下，满足联络线传输极限 C12 约束的区域 1 最小临界惯性 H1。
"""
function find_critical_inertia_tieline(
	D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
	H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
	T12::Float64, C12::Float64;
	H_min_search::Float64 = 0.05, H_max_search::Float64 = 100.0, tol::Float64 = 1e-3,
)
    p_min_H = simulate_multiarea_frequency_unclamped(
        H_min_search, D1, R1, Tg1, Km1, DP1,
        H2, D2, R2, Tg2, Km2, DP2,
        T12,
    )
    # In this model the peak tie-line transfer can increase with local inertia:
    # a slower frequency excursion gives the interconnection longer to exchange
    # power. Therefore this is an *upper* inertia constraint, not a lower one.
    if !isfinite(p_min_H) || p_min_H > C12
        # The lower endpoint is outside the valid finite-transfer branch.  It
        # is not an upper tie-line boundary; returning H_min here would create
        # a spurious zero-width island in the feasible polygon.  The local
        # stability/ROCOF/nadir lower bounds handle that endpoint instead.
        return H_max_search
    end

    p_max_H = simulate_multiarea_frequency_unclamped(
        H_max_search, D1, R1, Tg1, Km1, DP1,
        H2, D2, R2, Tg2, Km2, DP2,
        T12,
    )
    if isfinite(p_max_H) && p_max_H <= C12
        return H_max_search
    end

	low = H_min_search
	high = H_max_search
	mid = 0.5 * (low + high)

	while (high - low) > tol
		mid = 0.5 * (low + high)
		p_val = simulate_multiarea_frequency_unclamped(
			mid, D1, R1, Tg1, Km1, DP1,
			H2, D2, R2, Tg2, Km2, DP2,
			T12,
		)
        if isfinite(p_val) && p_val <= C12
            low = mid
        else
            high = mid
		end
	end

	return mid
end

"""
    simulate_multiarea_frequency_history(...) -> Tuple{Vector, Vector, Vector, Vector}

English: Simulates the dynamic frequency response of a 2-area power system and returns the state histories.
Chinese: 模拟双区域互联系统的频率响应，返回时间、双区频率偏差以及联络线功率的历史时间序列。
"""
function simulate_multiarea_frequency_history(
	H1::Float64, D1::Float64, R1::Float64, Tg1::Float64, Km1::Float64, DP1::Float64,
	H2::Float64, D2::Float64, R2::Float64, Tg2::Float64, Km2::Float64, DP2::Float64,
	T12::Float64, C12::Float64;
	t_max::Float64 = 10.0, dt::Float64 = 0.005,
)
	df1 = 0.0
	xg1 = 0.0
	df2 = 0.0
	xg2 = 0.0
	P_tie = 0.0

	n_steps = round(Int, t_max / dt)

	t_history = zeros(n_steps + 1)
	df1_history = zeros(n_steps + 1)
	df2_history = zeros(n_steps + 1)
	P_tie_history = zeros(n_steps + 1)

	t_history[1] = 0.0
	df1_history[1] = df1
	df2_history[1] = df2
	P_tie_history[1] = P_tie

	for step in 1:n_steps
		function get_derivatives(df1_val, xg1_val, df2_val, xg2_val, P_tie_val)
			Pm1 = - Km1 * R1 * df1_val + (1.0 - Km1) * xg1_val
			Pm2 = - Km2 * R2 * df2_val + (1.0 - Km2) * xg2_val

			ddf1 = (Pm1 - D1 * df1_val - DP1 + P_tie_val) / H1
			dxg1 = - (df1_val * R1 / Tg1) - (xg1_val / Tg1)

			ddf2 = (Pm2 - D2 * df2_val - DP2 - P_tie_val) / H2
			dxg2 = - (df2_val * R2 / Tg2) - (xg2_val / Tg2)

			dP_tie = 2.0 * pi * T12 * (df2_val - df1_val)

			if P_tie_val >= C12 && dP_tie > 0.0
				dP_tie = 0.0
			elseif P_tie_val <= -C12 && dP_tie < 0.0
				dP_tie = 0.0
			end

			return ddf1, dxg1, ddf2, dxg2, dP_tie
		end

		# RK4 steps
		k1_df1, k1_xg1, k1_df2, k1_xg2, k1_Ptie = get_derivatives(df1, xg1, df2, xg2, P_tie)

		k2_df1, k2_xg1, k2_df2, k2_xg2, k2_Ptie = get_derivatives(
			df1 + 0.5*dt*k1_df1, xg1 + 0.5*dt*k1_xg1,
			df2 + 0.5*dt*k1_df2, xg2 + 0.5*dt*k1_xg2,
			clamp(P_tie + 0.5*dt*k1_Ptie, -C12, C12),
		)

		k3_df1, k3_xg1, k3_df2, k3_xg2, k3_Ptie = get_derivatives(
			df1 + 0.5*dt*k2_df1, xg1 + 0.5*dt*k2_xg1,
			df2 + 0.5*dt*k2_df2, xg2 + 0.5*dt*k2_xg2,
			clamp(P_tie + 0.5*dt*k2_Ptie, -C12, C12),
		)

		k4_df1, k4_xg1, k4_df2, k4_xg2, k4_Ptie = get_derivatives(
			df1 + dt*k3_df1, xg1 + dt*k3_xg1,
			df2 + dt*k3_df2, xg2 + dt*k3_xg2,
			clamp(P_tie + dt*k3_Ptie, -C12, C12),
		)

		df1 += (dt / 6.0) * (k1_df1 + 2.0*k2_df1 + 2.0*k3_df1 + k4_df1)
		xg1 += (dt / 6.0) * (k1_xg1 + 2.0*k2_xg1 + 2.0*k3_xg1 + k4_xg1)
		df2 += (dt / 6.0) * (k1_df2 + 2.0*k2_df2 + 2.0*k3_df2 + k4_df2)
		xg2 += (dt / 6.0) * (k1_xg2 + 2.0*k2_xg2 + 2.0*k3_xg2 + k4_xg2)
		P_tie = clamp(P_tie + (dt / 6.0) * (k1_Ptie + 2.0*k2_Ptie + 2.0*k3_Ptie + k4_Ptie), -C12, C12)

		t_history[step + 1] = step * dt
		df1_history[step + 1] = df1
		df2_history[step + 1] = df2
		P_tie_history[step + 1] = P_tie
	end

	return t_history, df1_history, df2_history, P_tie_history
end
