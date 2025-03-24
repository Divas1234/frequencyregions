
import numpy as np
from mpl_toolkits.mplot3d import Axes3D
import matplotlib.pyplot as plt

def create_irregular_shape():
    # 定义不规则几何体的顶点坐标
    vertices = np.array([
        [0, 0, 0],    # 底部顶点
        [1, 0, 0],
        [1, 1, 0],
        [0, 1, 0],
        [0.5, 0.5, 2],  # 顶部顶点
    ])

    # 定义面的顶点索引
    faces = [
        [0, 1, 4],    # 侧面
        [1, 2, 4],
        [2, 3, 4],
        [3, 0, 4],
        [0, 1, 2, 3]  # 底面
    ]

    # 创建3D图形
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')

    # 绘制每个面
    for face in faces:
        x = vertices[face, 0]
        y = vertices[face, 1]
        z = vertices[face, 2]
        ax.plot_trisurf(x, y, z)

    # 设置坐标轴标签
    ax.set_xlabel('X')
    ax.set_ylabel('Y')
    ax.set_zlabel('Z')

    # 显示图形
    plt.show()

if __name__ == "__main__":
    create_irregular_shape()
