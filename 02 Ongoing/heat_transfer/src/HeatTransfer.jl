# # HeatTransfer.jl — 传热模块
#
# 1D / 2D 瞬态热传导有限差分求解器。
# 支持 Dirichlet / Neumann / Robin 边界条件，多种热源模式，
# 以及稳态 / 瞬态两种求解模式。
#
# # 快速上手
# ```julia
# using .HeatTransfer
#
# # 1D 瞬态：两端恒温的铜棒
# mesh = UniformMesh1D(0.0, 1.0, 100)
# mat = Material(alpha=1.17e-4, k=401.0, ρ=8960.0, cp=385.0)
# prob = HeatProblem1D(mesh, mat;
#     T_left  = BoundaryCondition(:dirichlet, 300.0),
#     T_right = BoundaryCondition(:dirichlet, 400.0),
#     T_init  = 300.0,
#     source  = ConstantSource(0.0),
# )
# result = solve_transient(prob, Δt=1.0, nsteps=100)
# ```

module HeatTransfer

using LinearAlgebra, SparseArrays
using Printf, Statistics
using Plots

# ============================================================================
# 物理参数与网格
# ============================================================================

"""材料参数"""
struct Material{T<:AbstractFloat}
    α::T      # 热扩散率 [m²/s]
    k::T      # 导热系数 [W/(m·K)]
    ρ::T      # 密度 [kg/m³]
    cp::T     # 比热容 [J/(kg·K)]
end
Material(; alpha, k, ρ, cp) = Material(Float64(alpha), Float64(k), Float64(ρ), Float64(cp))

"""1D 均匀网格"""
struct UniformMesh1D{T<:AbstractFloat}
    x_start::T
    x_end::T
    nx::Int
    dx::T
    xv::Vector{T}  # 节点坐标列
end
function UniformMesh1D(x_start, x_end, nx)
    dx = (x_end - x_start) / (nx - 1)
    xv = range(x_start, x_end, length=nx) |> collect
    UniformMesh1D(Float64(x_start), Float64(x_end), nx, Float64(dx), xv)
end

"""2D 均匀矩形网格"""
struct UniformMesh2D{T<:AbstractFloat}
    x_start::T;  x_end::T
    y_start::T;  y_end::T
    nx::Int;     ny::Int
    dx::T;       dy::T
    xv::Vector{T}
    yv::Vector{T}
end
function UniformMesh2D(x_start, x_end, nx, y_start, y_end, ny)
    dx = (x_end - x_start) / (nx - 1)
    dy = (y_end - y_start) / (ny - 1)
    xv = range(x_start, x_end, length=nx) |> collect
    yv = range(y_start, y_end, length=ny) |> collect
    UniformMesh2D(Float64(x_start), Float64(x_end), Float64(y_start), Float64(y_end),
                  nx, ny, Float64(dx), Float64(dy), xv, yv)
end

# ============================================================================
# 边界条件
# ============================================================================

@enum BCTYPE begin
    DIRICHLET   # T = value
    NEUMANN     # ∂T/∂n = value
    ROBIN       # k·∂T/∂n + h·(T - T∞) = 0
end

struct BoundaryCondition{T<:AbstractFloat}
    btype::BCTYPE
    value::T           # Dirichlet/Neumann: 值; Robin: h
    T_inf::T           # Robin 环境温度 (Dirichlet/Neumann 忽略)
end
BoundaryCondition(btype::BCTYPE, value) = BoundaryCondition(btype, Float64(value), 0.0)
BoundaryCondition(btype::BCTYPE, value, T_inf) = BoundaryCondition(btype, Float64(value), Float64(T_inf))

BoundaryCondition(::Val{:dirichlet}, value) = BoundaryCondition(DIRICHLET, value)
BoundaryCondition(::Val{:neumann},  value) = BoundaryCondition(NEUMANN, value)
BoundaryCondition(::Val{:robin},   value, T_inf) = BoundaryCondition(ROBIN, value, T_inf)
# Symbol / 字符串便利构造
BoundaryCondition(s::Symbol, args...) =
    BoundaryCondition(Val{s}(), args...)
BoundaryCondition(s::AbstractString, args...) =
    BoundaryCondition(Val{Symbol(s)}(), args...)

# ============================================================================
# 热源
# ============================================================================

abstract type AbstractSource end

"""均匀体积热源 Q [W/m³]"""
struct ConstantSource{T<:AbstractFloat} <: AbstractSource
    Q::T
end
ConstantSource(Q) = ConstantSource(Float64(Q))

"""仅在某区域生效的均匀热源"""
struct RegionSource{T<:AbstractFloat} <: AbstractSource
    Q::T
    x_range::Tuple{T,T}
    y_range::Union{Nothing,Tuple{T,T}}
end
RegionSource(Q, x_range; y_range=nothing) =
    RegionSource(Float64(Q), (Float64(x_range[1]), Float64(x_range[2])), y_range)

function source_value(src::AbstractSource, x, y=nothing)::Float64
    if src isa ConstantSource
        return src.Q
    elseif src isa RegionSource
        if src.y_range === nothing  # 1D
            return src.x_range[1] ≤ x ≤ src.x_range[2] ? src.Q : 0.0
        else
            return (src.x_range[1] ≤ x ≤ src.x_range[2] &&
                    src.y_range[1] ≤ y ≤ src.y_range[2]) ? src.Q : 0.0
        end
    end
    return 0.0
end

# ============================================================================
# 问题定义
# ============================================================================

"""1D 瞬态热传导问题"""
struct HeatProblem1D{T<:AbstractFloat}
    mesh::UniformMesh1D{T}
    mat::Material{T}
    T_left::BoundaryCondition{T}
    T_right::BoundaryCondition{T}
    T_init::Union{T,Vector{T}}
    source::AbstractSource
end
function HeatProblem1D(mesh, mat;
        T_left=BoundaryCondition(DIRICHLET, 0.0),
        T_right=BoundaryCondition(DIRICHLET, 0.0),
        T_init=0.0, source=ConstantSource(0.0))
    HeatProblem1D(mesh, mat, T_left, T_right, T_init, source)
end

"""2D 瞬态热传导问题"""
struct HeatProblem2D{T<:AbstractFloat}
    mesh::UniformMesh2D{T}
    mat::Material{T}
    T_left::BoundaryCondition{T}
    T_right::BoundaryCondition{T}
    T_bottom::BoundaryCondition{T}
    T_top::BoundaryCondition{T}
    T_init::Union{T,Matrix{T}}
    source::AbstractSource
end
function HeatProblem2D(mesh, mat;
        T_left=BoundaryCondition(DIRICHLET, 0.0),
        T_right=BoundaryCondition(DIRICHLET, 0.0),
        T_bottom=BoundaryCondition(DIRICHLET, 0.0),
        T_top=BoundaryCondition(DIRICHLET, 0.0),
        T_init=0.0, source=ConstantSource(0.0))
    HeatProblem2D(mesh, mat, T_left, T_right, T_bottom, T_top, T_init, source)
end

# ============================================================================
# 1D 稳态求解器
# ============================================================================

"""
    assemble_stiffness_1d(prob::HeatProblem1D) -> (K, f)

组装 1D 稳态有限差分刚度矩阵 `K` 和右端项 `f`。
`K * T = f` 即离散后的稳态温度场。
"""
function assemble_stiffness_1d(prob::HeatProblem1D)
    m = prob.mesh;  mat = prob.mat
    nx = m.nx;  dx = m.dx
    K = spzeros(nx, nx)
    f = zeros(nx)

    # 内点：(-k/dx²) * T_{i-1} + (2k/dx²) * T_i + (-k/dx²) * T_{i+1} = Q_i
    coef = mat.k / dx^2
    for i in 2:nx-1
        K[i, i-1] = -coef
        K[i, i]   =  2.0 * coef
        K[i, i+1] = -coef
        f[i] = source_value(prob.source, m.xv[i])
    end

    # 左边界
    _apply_bc_1d!(K, f, prob.T_left, m.xv[1], dx, mat.k, 1, nx)

    # 右边界
    _apply_bc_1d!(K, f, prob.T_right, m.xv[end], dx, mat.k, nx, nx)

    return K, f
end

function _apply_bc_1d!(K, f, bc::BoundaryCondition, x, dx, k, idx, nx)
    if bc.btype == DIRICHLET
        K[idx, :] .= 0.0
        K[idx, idx] = 1.0
        f[idx] = bc.value
    elseif bc.btype == NEUMANN
        # 一阶前向/后向差分
        if idx == 1
            K[1, 1] = -k / dx;  K[1, 2] = k / dx
            f[1] = bc.value
        else
            K[nx, nx-1] = -k / dx;  K[nx, nx] = k / dx
            f[nx] = bc.value
        end
    elseif bc.btype == ROBIN
        # -k·∂T/∂n = h·(T - T∞) → 一阶差分离散
        if idx == 1
            # (T₂ - T₁)/dx = -(h/k)·(T₁ - T∞)
            # → T₁·(-1/dx - h/k) + T₂/dx = -h·T∞/k
            K[1, 1] = -k/dx - bc.value     # bc.value = h
            K[1, 2] =  k/dx
            f[1] = -bc.value * bc.T_inf
        else
            # (T_{nx} - T_{nx-1})/dx = -(h/k)·(T_{nx} - T∞)
            K[nx, nx-1] = -k/dx
            K[nx, nx]  =  k/dx + bc.value   # bc.value = h
            f[nx] = bc.value * bc.T_inf
        end
    end
    return nothing
end

"""1D 稳态求解"""
function solve_steady(prob::HeatProblem1D)
    K, f = assemble_stiffness_1d(prob)
    T = K \ f
    return T
end

# ============================================================================
# 1D 瞬态求解器 (隐式 Euler / Crank-Nicolson)
# ============================================================================

@enum SCHEME IMPLICIT_EULER CRANK_NICOLSON

"""
    solve_transient(prob::HeatProblem1D; Δt=1.0, nsteps=100, scheme=CRANK_NICOLSON,
        output_every=1) -> Matrix{Float64}

1D 瞬态求解，返回 `(nsteps+1) × nx` 温度矩阵（每行一个时间步）。
"""
function solve_transient(prob::HeatProblem1D; Δt=1.0, nsteps=100,
        scheme::SCHEME=CRANK_NICOLSON, output_every=1)
    m = prob.mesh;  mat = prob.mat
    nx = m.nx;  dx = m.dx
    α = mat.α    # 热扩散率

    # 初始化温度场
    T = zeros(nsteps + 1, nx)
    if prob.T_init isa AbstractVector
        T[1, :] .= prob.T_init
    else
        T[1, :] .= prob.T_init
    end

    r = α * Δt / dx^2   # 傅里叶数
    θ = (scheme == CRANK_NICOLSON) ? 0.5 : 1.0   # IE=1, C-N=0.5

    # 组装左端矩阵 A： (I + θ·r·L)
    # L 是标准拉普拉斯算子（不含边界）
    L = spzeros(nx, nx)
    for i in 2:nx-1
        L[i, i-1] = -1
        L[i, i]   =  2
        L[i, i+1] = -1
    end
    A = I + θ * r * L    # sparse identity

    # 时间推进
    for n in 1:nsteps
        T_old = T[n, :]
        rhs = copy(T_old)

        # 内点：扩散项的显式部分 + 热源
        for i in 2:nx-1
            lap_explicit = (T_old[i-1] - 2*T_old[i] + T_old[i+1]) / dx^2
            rhs[i] += (1 - θ) * Δt * α * lap_explicit +
                      Δt * source_value(prob.source, m.xv[i]) / (mat.ρ * mat.cp)
        end

        # 标记隐式扩散贡献（内点已包含在 A 中，边界特殊处理
        # 但需注意边界行 A[i,:] 已预设 Dirichlet 等）

        # 边界条件（覆盖 A 和 rhs 的边界行）
        _apply_bc_transient_1d!(A, rhs, prob.T_left, prob.T_right,
                                m, dx, α, Δt, θ, nx, T_old)

        # 解线性系统
        T_new = A \ rhs
        T[n+1, :] = T_new
    end

    # 仅保留 output_every 步
    if output_every > 1
        T = T[1:output_every:end, :]
    end
    return T
end

function _apply_bc_transient_1d!(A, rhs, bc_left, bc_right, m, dx, α, Δt, θ, nx, T_old)
    # 左边界 Dirichlet
    if bc_left.btype == DIRICHLET
        A[1, :] .= 0.0;  A[1, 1] = 1.0
        rhs[1] = bc_left.value
    elseif bc_left.btype == NEUMANN
        # ∂T/∂n = q → 虚节点法
        # T₀ = T₂ - 2*dx*q
        A[1, 1] = 1.0;  A[1, 2] = 0.0
        rhs[1] = rhs[2] - 2 * dx * bc_left.value   # 简化近似
    elseif bc_left.btype == ROBIN
        # -k·∂T/∂n = h·(T - T∞)
        A[1, 1] = 1.0 + θ * α * Δt / dx^2 * (1 + bc_left.value * dx / m.k)
        # ... 完整实现略（典型项目中用 full Newton 或半隐）
        @warn "Robin BC in transient not fully implemented, falling back to Dirichlet approximation"
        A[1, :] .= 0.0;  A[1, 1] = 1.0
        rhs[1] = bc_left.value
    end

    # 右边界 — 对称逻辑
    if bc_right.btype == DIRICHLET
        A[nx, :] .= 0.0;  A[nx, nx] = 1.0
        rhs[nx] = bc_right.value
    elseif bc_right.btype == NEUMANN
        A[nx, nx] = 1.0;  A[nx, nx-1] = 0.0
        rhs[nx] = rhs[nx-1] - 2 * dx * bc_right.value
    elseif bc_right.btype == ROBIN
        A[nx, nx] = 1.0 + θ * α * Δt / dx^2 * (1 + bc_right.value * dx / m.k)
        @warn "Robin BC in transient not fully implemented, falling back to Dirichlet approximation"
        A[nx, :] .= 0.0;  A[nx, nx] = 1.0
        rhs[nx] = bc_right.value
    end
    return nothing
end

# ============================================================================
# 2D 稳态求解器
# ============================================================================

function _ij_to_n(i, j, nx)::Int
    return (j - 1) * nx + i
end

"""
    assemble_stiffness_2d(prob::HeatProblem2D) -> (K, f)

2D 稳态有限差分组装。节点排列为列优先 (column-major)：
  T[i,j] → index = (j-1)*nx + i
"""
function assemble_stiffness_2d(prob::HeatProblem2D)
    m = prob.mesh;  mat = prob.mat
    nx, ny = m.nx, m.ny
    ntot = nx * ny
    K = spzeros(ntot, ntot)
    f = zeros(ntot)

    dx, dy = m.dx, m.dy
    cx = mat.k / dx^2
    cy = mat.k / dy^2

    for j in 1:ny, i in 1:nx
        idx = _ij_to_n(i, j, nx)

        # 角点：用平均或取其中一条边的值（这里用 x 方向为默认）
        if (i == 1 && j == 1)
            # 左下角 — 取左边界（或底部）
            _apply_bc_2d_edge!(K, f, prob.T_left, idx, i, j, nx, ny, dx, mat.k, :left)
        elseif (i == nx && j == 1)
            # 右下角
            _apply_bc_2d_edge!(K, f, prob.T_right, idx, i, j, nx, ny, dx, mat.k, :right)
        elseif (i == 1 && j == ny)
            # 左上角
            _apply_bc_2d_edge!(K, f, prob.T_top, idx, i, j, nx, ny, dy, mat.k, :top)
        elseif (i == nx && j == ny)
            # 右上角
            _apply_bc_2d_edge!(K, f, prob.T_top, idx, i, j, nx, ny, dy, mat.k, :top)
        elseif i == 1
            _apply_bc_2d_edge!(K, f, prob.T_left, idx, i, j, nx, ny, dx, mat.k, :left)
        elseif i == nx
            _apply_bc_2d_edge!(K, f, prob.T_right, idx, i, j, nx, ny, dx, mat.k, :right)
        elseif j == 1
            _apply_bc_2d_edge!(K, f, prob.T_bottom, idx, i, j, nx, ny, dy, mat.k, :bottom)
        elseif j == ny
            _apply_bc_2d_edge!(K, f, prob.T_top, idx, i, j, nx, ny, dy, mat.k, :top)
        else
            # 内点：五点点拉普拉斯
            K[idx, idx] = 2cx + 2cy
            K[idx, _ij_to_n(i-1, j, nx)] = -cx
            K[idx, _ij_to_n(i+1, j, nx)] = -cx
            K[idx, _ij_to_n(i, j-1, nx)] = -cy
            K[idx, _ij_to_n(i, j+1, nx)] = -cy
            f[idx] = source_value(prob.source, m.xv[i], m.yv[j])
        end
    end
    return K, f
end

function _apply_bc_2d_edge!(K, f, bc::BoundaryCondition, idx, i, j, nx, ny, d, k, edge)
    if bc.btype == DIRICHLET
        K[idx, :] .= 0.0
        K[idx, idx] = 1.0
        f[idx] = bc.value
    elseif bc.btype == NEUMANN
        # 通量边界：虚节点法 → 修改控制方程
        K[idx, idx] = 2k / d^2 + 2k / (i == 1 || i == nx ? dy^2 : dx^2)  # 近似
        f[idx] = bc.value * k / d  # 简化
    elseif bc.btype == ROBIN
        K[idx, idx] = 2k / d^2 + 2k / (i == 1 || i == nx ? dy^2 : dx^2) + 2 * bc.value / d
        f[idx] = 2 * bc.value * bc.T_inf / d
    end
    return nothing
end

"""2D 稳态求解"""
function solve_steady(prob::HeatProblem2D)
    K, f = assemble_stiffness_2d(prob)
    T_vec = K \ f
    return reshape(T_vec, prob.mesh.nx, prob.mesh.ny)
end

# ============================================================================
# 后处理
# ============================================================================

"""
    plot_temperature_field(xv, yv, T, title="Temperature Field")

绘制 2D 温度场云图。
"""
function plot_temperature_field(xv, yv, T; title="Temperature Field", kw...)
    Plots.heatmap(xv, yv, permutedims(T); xlabel="x [m]", ylabel="y [m]", title=title, kw...)
end

"""
    plot_temperature_profile(x, T, title="Temperature Profile"; kwargs...)

绘制 1D 温度分布曲线。
"""
function plot_temperature_profile(x, T; title="Temperature Profile", kwargs...)
    Plots.plot(x, T, xlabel="x [m]", ylabel="T [K]", title=title, lw=2, kwargs...)
end

"""
    animate_transient(xv, T_matrix; title="Transient Temperature", show_every=5, fps=15)

生成瞬态温度演变动画。
返回 Plots.Animation 对象。
"""
function animate_transient(xv, T_matrix; title="Transient Temperature",
        show_every=1, fps=15)
    n_frames = size(T_matrix, 1)
    anim = Plots.@animate for n in 1:show_every:n_frames
        plot_temperature_profile(xv, T_matrix[n, :];
            title=@sprintf("%s, t_step=%d", title, n),
            ylims=(minimum(T_matrix) * 0.95, maximum(T_matrix) * 1.05))
    end every 1 fps=fps
    return anim
end

# ============================================================================
# 分析工具
# ============================================================================

"""
    compute_heat_flux(T, dx, k) -> Vector{Float64}

用中心差分计算热流密度 q = -k·dT/dx。
"""
function compute_heat_flux(T, dx, k)
    n = length(T)
    q = zeros(n)
    q[1] = -k * (T[2] - T[1]) / dx          # 前向差分
    for i in 2:n-1
        q[i] = -k * (T[i+1] - T[i-1]) / (2dx)  # 中心差分
    end
    q[end] = -k * (T[end] - T[end-1]) / dx  # 后向差分
    return q
end

"""
    compute_heat_flux_2d(T::Matrix, dx, dy, k) -> (qx, qy)
"""
function compute_heat_flux_2d(T, dx, dy, k)
    nx, ny = size(T)
    qx = zeros(nx, ny)
    qy = zeros(nx, ny)

    # 内点中心差分
    for j in 2:ny-1, i in 2:nx-1
        qx[i, j] = -k * (T[i+1, j] - T[i-1, j]) / (2dx)
        qy[i, j] = -k * (T[i, j+1] - T[i, j-1]) / (2dy)
    end
    # 边界（前向/后向）
    for j in 1:ny
        qx[1, j]  = -k * (T[2,  j] - T[1,  j]) / dx
        qx[nx, j] = -k * (T[nx, j] - T[nx-1, j]) / dx
    end
    for i in 1:nx
        qy[i, 1]  = -k * (T[i, 2]  - T[i, 1])  / dy
        qy[i, ny] = -k * (T[i, ny] - T[i, ny-1]) / dy
    end
    return qx, qy
end

"""
    total_heat_content(T, ρ, cp, dx) -> Float64

计算系统的总热容量（1D）。
"""
total_heat_content(T, ρ, cp, dx) = ρ * cp * dx * sum(T)

"""
    average_temperature(T) -> Float64

平均温度。
"""
average_temperature(T) = mean(T)

export
    # 类型
    Material,
    UniformMesh1D, UniformMesh2D,
    BoundaryCondition, DIRICHLET, NEUMANN, ROBIN, BCTYPE,
    ConstantSource, RegionSource, AbstractSource,
    HeatProblem1D, HeatProblem2D,
    SCHEME, IMPLICIT_EULER, CRANK_NICOLSON,

    # 求解器
    solve_steady, solve_transient,
    assemble_stiffness_1d, assemble_stiffness_2d,

    # 后处理
    plot_temperature_field, plot_temperature_profile,
    animate_transient,

    # 分析
    compute_heat_flux, compute_heat_flux_2d,
    total_heat_content, average_temperature,

    # 工具
    source_value

end # module
