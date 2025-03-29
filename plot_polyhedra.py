import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from scipy.spatial import ConvexHull

# 读取顶点数据
vertices = np.loadtxt('d:/GithubClonefiles/frequencyregions/res/all_vertices.txt')

# 创建3D图形
fig = plt.figure(figsize=(12, 8))
ax = fig.add_subplot(111, projection='3d')

# 获取唯一的下垂系数值
unique_x = np.unique(vertices[:, 0])

# 使用不同颜色绘制每个下垂系数对应的多面体
colors = plt.cm.viridis(np.linspace(0, 1, len(unique_x)))

# Store all polyhedron information for the legend
legend_elements = []

for i, x_val in enumerate(unique_x):
    # Get all points for the current droop coefficient
    current_vertices = vertices[vertices[:, 0] == x_val]
    
    # 绘制这些点
    ax.scatter(current_vertices[:, 0], current_vertices[:, 1], current_vertices[:, 2], 
               color=colors[i], s=30, alpha=0.7)
    
    # 如果点数足够，构建凸包
    if len(current_vertices) >= 4:
        try:
            # 使用第二列和第三列构建凸包（阻尼系数和惯量系数）
            hull = ConvexHull(current_vertices[:, 1:])
            
            # 获取凸包的面
            faces = []
            for simplex in hull.simplices:
                # 将下垂系数添加回来，形成3D坐标
                face_points = []
                for idx in simplex:
                    point = current_vertices[idx]
                    face_points.append(point)
                faces.append(face_points)
            
            # 绘制凸包并为每个多面体着色
            poly = Poly3DCollection(faces, alpha=0.3, facecolors=colors[i], edgecolor='black')
            ax.add_collection3d(poly)
            
            # Add to legend
            legend_elements.append(plt.Line2D([0], [0], color=colors[i], lw=4, label=f'{x_val:.2f}'))
        except Exception as e:
            print(f"无法为下垂系数 {x_val} 创建凸包: {e}")

# Set axis labels
ax.set_xlabel('Droop (p.u.)', fontsize=16)
ax.set_ylabel('Damping (p.u.)', fontsize=16)
ax.set_zlabel('Inertia (p.u.)', fontsize=16)

# Remove title

# Adjust view angle
ax.view_init(elev=30, azim=45)

# Set axis limits and invert Droop and Damping axes
ax.set_xlim(max(vertices[:, 0])+1, min(vertices[:, 0])-1)  # 反转X轴
ax.set_ylim(max(vertices[:, 1])+1, min(vertices[:, 1])-1)  # 反转Y轴
ax.set_zlim(min(vertices[:, 2])-1, max(vertices[:, 2])+1)

# 获取当前x轴的刻度位置
xticks = ax.get_xticks()
# 过滤掉范围外的刻度
xticks = xticks[(xticks >= min(vertices[:, 0])) & (xticks <= max(vertices[:, 0]))]
# 创建新的刻度标签（倒数）
xtick_labels = [f'{1/x:.3f}' for x in xticks]
# 设置新的刻度标签
ax.set_xticks(xticks)
ax.set_xticklabels(xtick_labels)

# Remove legend

# Remove grid
ax.grid(False)

# Set background transparent
ax.set_facecolor('none')
fig.patch.set_facecolor('none')

# Remove axis panes
ax.xaxis.pane.fill = False
ax.yaxis.pane.fill = False
ax.zaxis.pane.fill = False

# Set font properties
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['font.size'] = 14  # Increase default font size

# Set axis label font size and position
ax.set_xlabel('Droop (p.u.)', fontsize=16, labelpad=15)  # Increase labelpad value for more distance
ax.set_ylabel('Damping (p.u.)', fontsize=16, labelpad=15)
ax.set_zlabel('Inertia (p.u.)', fontsize=16, rotation=180, labelpad=15)

# Set tick font size
ax.tick_params(axis='both', which='major', labelsize=14)

# Display the plot
plt.tight_layout()

# Save the figure in different formats
plt.savefig('d:/GithubClonefiles/frequencyregions/fig/polyhedra_3d.svg',
            dpi=300, bbox_inches='tight', transparent=True)
plt.savefig('d:/GithubClonefiles/frequencyregions/fig/polyhedra_3d.pdf', 
            dpi=300, bbox_inches='tight', transparent=True)

plt.show()
