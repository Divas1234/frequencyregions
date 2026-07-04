# # 1D 热传导示例
# 铜棒，两端恒温 300K / 400K，稳态 + 瞬态求解

using Pkg
Pkg.activate(@__DIR__)
push!(LOAD_PATH, @__DIR__)
using .HeatTransfer
using Plots

println("="^60)
println("1D 热传导 — 铜棒 (Cu)")
println("="^60)

# ===== 材料参数（铜） =====
copper = Material(
    alpha = 1.17e-4,   # 热扩散率 [m²/s]
    k     = 401.0,      # 导热系数 [W/(m·K)]
    ρ     = 8960.0,     # 密度 [kg/m³]
    cp    = 385.0,      # 比热容 [J/(kg·K)]
)

# ===== 网格 =====
L = 1.0                # 长度 [m]
nx = 100               # 节点数
mesh = UniformMesh1D(0.0, L, nx)
@printf("网格: nx=%d, dx=%.4f m\n", nx, mesh.dx)

# ===== 问题：两端恒温，无内热源 =====
prob = HeatProblem1D(
    mesh, copper;
    T_left  = BoundaryCondition(:dirichlet, 300.0),
    T_right = BoundaryCondition(:dirichlet, 400.0),
    T_init  = 300.0,
    source  = ConstantSource(0.0),
)

println("\n--- 稳态求解 ---")
T_steady = solve_steady(prob)
@printf("入口温度:  %.2f K\n", T_steady[1])
@printf("出口温度:  %.2f K\n", T_steady[end])
@printf("平均温度:  %.2f K\n", average_temperature(T_steady))

# 热流
q = compute_heat_flux(T_steady, mesh.dx, copper.k)
@printf("入口热流:  %.1f W/m²\n", q[1])
@printf("出口热流:  %.1f W/m²\n", q[end])
@printf("热流守恒偏差: %.2e W/m²\n", q[1] + q[end])

p1 = plot_temperature_profile(mesh.xv, T_steady;
    title="1D Steady-State Temperature (Dirichlet BC)")

println("\n--- 瞬态求解 ---")
println("使用 Crank-Nicolson 格式, Δt=2.0 s, 500 步")
T_trans = solve_transient(prob; Δt=2.0, nsteps=500, scheme=CRANK_NICOLSON, output_every=50)
@printf("最终时刻平均温度: %.2f K\n", average_temperature(T_trans[end, :]))

# 瞬态动画
println("\n--- 生成瞬态动画 ---")
anim = animate_transient(mesh.xv, T_trans; show_every=20)
gif(anim, "examples/transient_1d.gif"; fps=10)
println("动画已保存: examples/transient_1d.gif")

# 瞬态快照
p2 = plot_temperature_profile(mesh.xv, T_trans[1, :]; label="t=0s", ls=:dash)
for (n, label) in [(end, "steady")]
    plot_temperature_profile!(mesh.xv, T_trans[end, :]; label="t=1000s", lw=2)
end
p2 = plot_temperature_profile(mesh.xv, T_trans[1, :]; label="t=0s", ls=:dash, lw=2)
for (row, t_label) in [
    (size(T_trans,1)÷5, @sprintf("t=%.0fs", 2*size(T_trans,1)÷5)),
    (size(T_trans,1)÷2, @sprintf("t=%.0fs", size(T_trans,1))),
    (size(T_trans,1),   "t=1000s (steady)"),
]
    plot_temperature_profile!(mesh.xv, T_trans[row, :]; label=t_label, lw=2)
end
plot_temperature_profile!(mesh.xv, T_steady; label="steady (direct)", ls=:dot, lw=2)

# 保存
savefig(p1, "examples/steady_1d.png")
savefig(p2, "examples/transient_1d.png")
println("稳态图已保存: examples/steady_1d.png")
println("瞬态图已保存: examples/transient_1d.png")

# ===== 验证：与解析解对比 =====
println("\n" * "="^60)
println("验证：稳态解析解")
println("="^60)
# 1D 无内热源 Dirichlet: T(x) = T_left + (T_right - T_left) * x/L
T_analytic = 300.0 .+ 100.0 * mesh.xv / L
rmse = sqrt(mean((T_steady - T_analytic).^2))
@printf("与解析解的 RMSE: %.6f K\n", rmse)
@printf("最大误差:        %.6f K\n", maximum(abs.(T_steady - T_analytic)))

p3 = Plots.plot(mesh.xv, T_steady, lw=3, label="FDM")
Plots.plot!(mesh.xv, T_analytic, lw=2, ls=:dash, label="Analytical")
Plots.title!("FDM vs Analytical Solution")
Plots.xlabel!("x [m]"); Plots.ylabel!("T [K]")
savefig(p3, "examples/validation_1d.png")
println("验证图已保存: examples/validation_1d.png")

println("\n✓ 1D 热传导示例完成!")
