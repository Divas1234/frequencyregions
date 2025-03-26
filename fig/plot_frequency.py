import numpy as np
import matplotlib.pyplot as plt

# Set scientific style
plt.rcParams.update({
    'font.family': 'Times New Roman',
    'font.size': 12,
    'axes.labelsize': 12,
    'axes.titlesize': 12,
    'xtick.labelsize': 10,
    'ytick.labelsize': 10,
    'legend.fontsize': 10,
    'axes.spines.top': True,
    'axes.spines.right': True,
    'axes.grid': False
})

# 创建时间数据点
t = np.linspace(0, 10, 1000)

# 创建VIC-PSO的频率变化数据
def vic_pso(t):
    y = np.zeros_like(t)
    mask1 = t < 1
    mask2 = (t >= 1) & (t < 2)
    mask3 = (t >= 2) & (t < 3)
    mask4 = (t >= 3) & (t < 4)
    mask5 = t >= 4
    
    # t < 1时保持0
    y[mask1] = 0
    
    # 1-2秒的快速下降
    y[mask2] = -0.075 * np.sin(np.pi * (t[mask2] - 1))
    
    # 2-3秒的振荡
    y[mask3] = 0.02 * np.sin(2 * np.pi * (t[mask3] - 2)) * np.exp(-1.5 * (t[mask3] - 2))
    
    # 3-4秒的小振荡
    y[mask4] = 0.005 * np.sin(2 * np.pi * (t[mask4] - 3)) * np.exp(-1.5 * (t[mask4] - 3))
    
    # 4秒后的衰减振荡
    y[mask5] = 0.002 * np.sin(np.pi * (t[mask5] - 4)) * np.exp(-0.5 * (t[mask5] - 4))
    
    return y

# 计算频率变化
df = vic_pso(t)

# 创建图形
plt.figure(figsize=(6, 4))
plt.plot(t, df, color='blue', linestyle='-', label='system frequency response', linewidth=2.0)

# Set axes
plt.xlabel('Time (s)')
plt.ylabel('Frequency Deviation, Δf (Hz)')
plt.ylim(-0.08, 0.02)

# Add legend with frame
plt.legend(frameon=True, edgecolor='black', fancybox=False)

# Adjust layout
plt.tight_layout()

# 保存图形
plt.savefig('frequency_response.pdf', dpi=300, bbox_inches='tight')
plt.close()