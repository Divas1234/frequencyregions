import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from scipy.spatial import ConvexHull
import os

def read_vertices_from_file(file_path):
    """从文本文件中读取顶点坐标"""
    vertices = []
    try:
        with open(file_path, 'r') as f:
            for line in f:
                # 假设每行包含x, y, z坐标，以空格分隔
                coords = list(map(float, line.strip().split()))
                if len(coords) >= 3:  # 确保至少有x, y, z三个坐标
                    vertices.append(coords[:3])  # 只取前三个值作为坐标
        return np.array(vertices)
    except FileNotFoundError:
        print(f"错误：找不到文件 '{file_path}'")
        print(f"当前工作目录: {os.getcwd()}")
        print(f"请确保提供了正确的文件路径")
        raise

def plot_convex_hull(vertices, output_file=None):
    """绘制凸包（凸多面体）"""
    # 创建凸包
    hull = ConvexHull(vertices)
    
    # 创建3D图形
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection='3d')
    
    # 不再绘制顶点标识
    # ax.scatter(vertices[:, 1], vertices[:, 0], vertices[:, 2], color='red', s=50, label='顶点')
    
    # 绘制凸包的面，但不显示内部连接线
    # 使用不同的方法绘制面和边缘
    
    # 首先绘制面，但不绘制边缘线
    for simplex in hull.simplices:
        # 注意：这里我们不需要改变simplex的顺序，因为它只是索引
        # 但在创建Poly3DCollection时，我们需要确保坐标的顺序是正确的
        face_vertices = vertices[simplex]
        # 创建新的点集，交换x和y坐标，并对y坐标取反以实现y轴旋转180度
        swapped_vertices = np.column_stack((face_vertices[:, 1], -face_vertices[:, 0], face_vertices[:, 2]))
        face = Poly3DCollection([swapped_vertices], alpha=0.3)
        face.set_color('lightblue')
        face.set_edgecolor('none')  # 不绘制边缘线
        ax.add_collection3d(face)
    
    # 然后单独绘制边缘线，确保每条边只绘制一次
    edges = set()
    for simplex in hull.simplices:
        n = len(simplex)
        for i in range(n):
            j = (i + 1) % n
            # 确保边的表示是有序的，以便正确检测重复
            edge = tuple(sorted([simplex[i], simplex[j]]))
            if edge not in edges:
                edges.add(edge)
    
    # 绘制所有唯一的边 - 互换x和y坐标，并对y坐标取反
    for edge in edges:
        ax.plot3D(
            [vertices[edge[0]][1], vertices[edge[1]][1]],      # y坐标作为x轴
            [-vertices[edge[0]][0], -vertices[edge[1]][0]],    # 取反的x坐标作为y轴
            [vertices[edge[0]][2], vertices[edge[1]][2]],
            color='black', linewidth=1.5
        )
    
    # 设置坐标轴标签 - 互换x和y轴标签
    ax.set_xlabel('damping (p.u.)')  # 原来的y轴标签
    ax.set_ylabel('droop (p.u.)')    # 原来的x轴标签
    ax.set_zlabel('inertia (p.u.)')
    
    # 设置标题
    ax.set_title('凸多面体区域')
    
    # 不再添加图例，因为没有顶点标识
    # ax.legend()
    
    # 调整视角以匹配图像，由于y轴旋转了180度，我们需要调整azim角度
    ax.view_init(elev=20, azim=135)  # 原来是-45，旋转180度后变为135
    
    # 将z轴放到坐标轴上
    ax.set_zlim(bottom=0)  # 确保z轴从0开始
    
    # 保存图像或显示
    if output_file:
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
    else:
        plt.show()

if __name__ == "__main__":
    import sys
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    if len(sys.argv) > 1:
        # 如果提供了相对路径，转换为绝对路径
        input_file = os.path.abspath(sys.argv[1])
        output_file = sys.argv[2] if len(sys.argv) > 2 else None
    else:
        # 默认文件路径，使用脚本所在目录下的all_vertices.txt
        input_file = os.path.join(script_dir, "all_vertices.txt")
        output_file = None
    
    try:
        print(f"尝试读取文件: {input_file}")
        if not os.path.exists(input_file):
            print(f"错误：找不到文件 '{input_file}'")
            print(f"当前工作目录: {os.getcwd()}")
            print(f"脚本目录: {script_dir}")
            print(f"可用文件: {os.listdir(script_dir)}")
            sys.exit(1)
            
        vertices = read_vertices_from_file(input_file)
        if len(vertices) < 4:
            print(f"错误：需要至少4个不共面的点来构建3D凸包，但只找到{len(vertices)}个点。")
            sys.exit(1)
        
        plot_convex_hull(vertices, output_file)
        print(f"成功绘制凸多面体，包含{len(vertices)}个顶点。")
    except Exception as e:
        print(f"发生错误：{e}")
        sys.exit(1)