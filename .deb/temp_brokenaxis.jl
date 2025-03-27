using Plots

# 生成示例数据
x = 1:10
y = [2, 4, 300, 150, 500, 450, 5, 6, 800, 850]

# 创建特殊布局
l = @layout [
    a{0.33h}    # 上部分占 33% 高度
    b{0.34h}    # 中间部分占 34% 高度
    c{0.33h}    # 下部分占 33% 高度
]

# 创建组合图
plot(
    plot(x, y, ylims=(700, 900), grid=true, showaxis=:y, 
         title="三段式断轴示例图", titlefontsize=10, legend=false,
         bottom_margin=-15Plots.px),
    begin
        p2 = plot(x, y, ylims=(250, 550), grid=true, showaxis=:y,
                 legend=true, ylabel="Y 轴",
                 bottom_margin=-15Plots.px,
                 top_margin=-15Plots.px,
                 label="数据1")
        # 添加第二个数据集
        x2 = x .+ 0.2  # 稍微错开 x 轴位置，避免重叠
        plot!(p2, x2, y .- 100, 
              marker=:square, 
              color=:red,
              label="数据2")
        p2
    end,
    plot(x, y, ylims=(0, 50), grid=true, 
         xlabel="X 轴", legend=false,
         top_margin=-15Plots.px),
    layout=l,
    size=(600, 800),
    marker=:circle,
    markersize=4,
    linewidth=2
)

# 保存图片
savefig("broken_axis_demo.png")