include("src/environment_config.jl")

# using GLMakie

using Plots
using Meshes

# 定义顶点
vertices = [
    Point(0, 0, 0),
    Point(1, 0, 0),
    Point(1, 1, 0),
    Point(0, 1, 0),
    Point(0, 0, 1),
    Point(1, 0, 1),
    Point(1, 1, 1),
    Point(0, 1, 1)
]

using Meshes, GLMakie
points = rand(Meshes.Point3f,10)
connec = connect.([(1,8),(1,10),(1,2,6,5),(2,4,6),(4,3,5,6),(3,1,5)], Ngon)
mesh = SimpleMesh(points, connec)
viz(mesh,facetcolor=:red,showfacets=false, segmentsize=10)

# 定义面
faces = [
    Face(1, 2, 3, 4),  # 底面
    Face(5, 6, 7, 8),  # 顶面
    Face(1, 2, 6, 5),  # 前面
    Face(2, 3, 7, 6),  # 右面
    Face(3, 4, 8, 7),  # 后面
    Face(4, 1, 5, 8)   # 左面
]

# 创建网格
mesh = SimpleMesh(vertices, faces)

# 绘制网格
plot(mesh, color=:blue, opacity=0.5, legend=false)