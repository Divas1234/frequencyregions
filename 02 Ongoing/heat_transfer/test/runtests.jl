@testset "HeatTransfer — 1D Steady" begin
    using .HeatTransfer
    using Statistics

    # 简单 1D 验证：两端 Dirichlet，无内热源
    mesh = UniformMesh1D(0.0, 1.0, 100)
    mat  = Material(alpha=1.0, k=1.0, ρ=1.0, cp=1.0)

    prob = HeatProblem1D(mesh, mat;
        T_left  = BoundaryCondition(:dirichlet, 300.0),
        T_right = BoundaryCondition(:dirichlet, 400.0),
        source  = ConstantSource(0.0),
    )
    T = solve_steady(prob)
    @test length(T) == 100
    @test T[1] ≈ 300.0
    @test T[end] ≈ 400.0

    # 解析解：T(x) = 300 + 100*x
    T_analytic = 300.0 .+ 100.0 * mesh.xv
    rmse = sqrt(mean((T - T_analytic).^2))
    @test rmse < 1e-10
end

@testset "HeatTransfer — 1D Steady Neumann" begin
    using .HeatTransfer

    # 左边界绝热 (q=0)，右边界恒温 T=400K
    mesh = UniformMesh1D(0.0, 1.0, 100)
    mat  = Material(alpha=1.0, k=1.0, ρ=1.0, cp=1.0)

    prob = HeatProblem1D(mesh, mat;
        T_left  = BoundaryCondition(:neumann, 0.0),
        T_right = BoundaryCondition(:dirichlet, 400.0),
        source  = ConstantSource(0.0),
    )
    T = solve_steady(prob)
    @test T[end] ≈ 400.0
    # 绝热左边界 → 全场均匀
    @test all(T .≈ 400.0)
end

@testset "HeatTransfer — 1D Steady with Heat Source" begin
    using .HeatTransfer

    mesh = UniformMesh1D(0.0, 1.0, 100)
    mat  = Material(alpha=1.0, k=1.0, ρ=1.0, cp=1.0)

    # 均匀内热源 Q=1000 W/m³，两端恒温 0K
    prob = HeatProblem1D(mesh, mat;
        T_left  = BoundaryCondition(:dirichlet, 0.0),
        T_right = BoundaryCondition(:dirichlet, 0.0),
        source  = ConstantSource(1000.0),
    )
    T = solve_steady(prob)
    # 解析解：T(x) = (Q/(2k))·x·(L-x)
    T_analytic = (1000.0 / 2.0) * mesh.xv .* (1.0 .- mesh.xv)
    rmse = sqrt(mean((T - T_analytic).^2))
    @test rmse < 1e-10
    @test T[1] ≈ 0.0 && T[end] ≈ 0.0
    @test T[div(100,2)] > T[1]  # 中点温度最高
end

@testset "HeatTransfer — Material" begin
    using .HeatTransfer

    copper = Material(alpha=1.17e-4, k=401.0, ρ=8960.0, cp=385.0)
    @test copper.α ≈ 1.17e-4
    @test copper.k ≈ 401.0
    @test copper.ρ ≈ 8960.0
    @test copper.cp ≈ 385.0
end

@testset "HeatTransfer — BoundaryCondition constructors" begin
    using .HeatTransfer

    bc1 = BoundaryCondition(:dirichlet, 300.0)
    @test bc1.btype == DIRICHLET
    @test bc1.value ≈ 300.0

    bc2 = BoundaryCondition(:neumann, 0.0)
    @test bc2.btype == NEUMANN

    bc3 = BoundaryCondition(:robin, 10.0, 300.0)
    @test bc3.btype == ROBIN
    @test bc3.value ≈ 10.0
    @test bc3.T_inf ≈ 300.0
end

@testset "HeatTransfer — Source value evaluation" begin
    using .HeatTransfer

    src1 = ConstantSource(500.0)
    @test source_value(src1, 0.5) ≈ 500.0

    src2 = RegionSource(1000.0, (0.3, 0.7))
    @test source_value(src2, 0.2) ≈ 0.0
    @test source_value(src2, 0.5) ≈ 1000.0
    @test source_value(src2, 0.8) ≈ 0.0
end

@testset "HeatTransfer — Heat flux" begin
    using .HeatTransfer

    # 线性温度分布 T = 300 + 100*x → q = -k * dT/dx = -k*100
    x = 0:0.01:1
    T = 300.0 .+ 100.0 * x
    q = compute_heat_flux(T, 0.01, 10.0)
    @test all(q .≈ -1000.0)  # q = -10 * 100
end

@testset "HeatTransfer — 1D Transient" begin
    using .HeatTransfer

    # 简单瞬态验证：两端 0K，初温 0K，无热源 → 温度不变
    mesh = UniformMesh1D(0.0, 1.0, 50)
    mat  = Material(alpha=1.0, k=1.0, ρ=1.0, cp=1.0)
    prob = HeatProblem1D(mesh, mat;
        T_left  = BoundaryCondition(:dirichlet, 0.0),
        T_right = BoundaryCondition(:dirichlet, 0.0),
        T_init  = 0.0,
        source  = ConstantSource(0.0),
    )
    T_trans = solve_transient(prob; Δt=0.1, nsteps=10, scheme=IMPLICIT_EULER)
    @test size(T_trans, 1) == 11  # 0..10 steps
    @test all(T_trans[end, :] .≈ 0.0)
end

@testset "HeatTransfer — 2D Steady" begin
    using .HeatTransfer

    mesh = UniformMesh2D(0.0, 1.0, 20, 0.0, 1.0, 20)
    mat  = Material(alpha=1.0, k=1.0, ρ=1.0, cp=1.0)
    prob = HeatProblem2D(mesh, mat;
        T_left   = BoundaryCondition(:dirichlet, 300.0),
        T_right  = BoundaryCondition(:dirichlet, 300.0),
        T_bottom = BoundaryCondition(:dirichlet, 300.0),
        T_top    = BoundaryCondition(:dirichlet, 400.0),
        source   = ConstantSource(0.0),
    )
    T = solve_steady(prob)
    @test size(T) == (20, 20)
    @test T[1, 1] ≈ 300.0   # 左下角
    @test T[end, end] ≈ 400.0  # 右上角
end
