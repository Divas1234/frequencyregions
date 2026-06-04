# 项目文件结构说明

## 概览

项目采用清晰的命名规范，使文件功能一目了然：

```
frequency-regions-analysis/
├── 【根目录执行脚本】
│   ├── run_single_droop_analysis.jl              # 单个droop参数频率区域分析
│   ├── run_batch_droop_analysis.jl               # 批量处理多个droop参数
│   ├── run_inertia_damping_comparison.jl         # 惯性与阻尼关系对比分析
│   ├── REFACTORING_GUIDE.md                      # 重构开发指南
│   ├── REFACTORING_SUMMARY.md                    # 重构改进总结
│   └── FILE_STRUCTURE.md                         # 本文档
│
└── src/
    ├── 【架构与配置 - 新增模块】
    │   ├── config_structures.jl                  # 类型安全的配置结构
    │   ├── validation.jl                         # 集中式验证模块
    │   ├── workflow_orchestrator.jl              # 工作流编排器
    │   └── environment_config.jl                 # 环境配置与全局常数
    │
    ├── 【计算核心模块】
    │   ├── sys_boundary_parameters.jl            # 系统边界参数定义
    │   ├── converter_config.jl                   # 转换器配置参数
    │   ├── core_inertia_damping_calculation.jl  # 惯性-阻尼核心计算
    │   ├── inertia_rocof_estimation.jl          # 基于ROCOF的惯性估计
    │   ├── frequency_response_analysis.jl        # 系统频率响应分析
    │   └── inertia_damping_fitting.jl            # 惯性-阻尼关系拟合
    │
    ├── 【可视化与几何模块】
    │   ├── visualization_generator.jl            # 2D绘图生成（破轴图等）
    │   ├── polyhedra_geometry_3d.jl              # 3D多面体几何生成
    │   ├── polygon_visualization_2d.jl           # 2D多边形可视化（凸包）
    │   └── interaction_plot_generation.jl        # 交互图表生成
    │
    └── 【工具模块】
        └── workflow_utilities.jl                 # 矩阵转换、文件I/O等工具

└── .deb/
    ├── demo.jl                                   # 多面体可视化演示
    └── debug.jl                                  # 调试脚本
```

## 文件功能详解

### 执行脚本 (根目录)

#### `run_single_droop_analysis.jl`
- **功能**: 对单一droop参数进行频率区域分析
- **输入**: 单个droop值（默认36.0）
- **输出**: 
  - `fig/output_plot.png/pdf` - 可视化图表
  - 4个顶点坐标
- **用途**: 快速验证和单参数分析

#### `run_batch_droop_analysis.jl`
- **功能**: 批量处理多个droop参数
- **输入**: droop范围（默认33-40，20个参数）
- **输出**:
  - `fig/batch_output_plot.png/pdf` - 批量结果图表
  - `res/all_vertices.txt` - 所有顶点数据
  - 多边形可视化图表
- **用途**: 参数扫描分析

#### `run_inertia_damping_comparison.jl`
- **功能**: 分析惯性与阻尼关系
- **用途**: 对比不同配置下的关系

### 架构模块 (新增)

#### `config_structures.jl` (410行)
类型安全的配置定义：
- `ControllerConfig` - 控制器参数
- `SystemParameters` - 系统参数
- `ComputationConfig` - 计算配置
- `ComputationResult` - 结构化计算结果
- `WorkflowState` - 工作流状态

#### `validation.jl` (290行)
统一的验证逻辑：
- `ValidationError` - 自定义异常类型
- 验证函数（controller、system、computation）
- 安全的验证包装器

#### `workflow_orchestrator.jl` (320行)
工作流编排和执行：
- `execute_workflow()` - 单个droop执行
- `execute_batch_workflow()` - 批量处理
- `validate_all_configurations()` - 配置验证

### 计算核心模块

#### `sys_boundary_parameters.jl`
系统参数定义：
- 默认边界条件
- 传统/现代电网模式参数
- 验证逻辑

#### `converter_config.jl`
转换器控制参数：
- VSM(虚拟同步机)配置
- Droop控制配置
- 时间常数、阻尼、惯性参数

#### `core_inertia_damping_calculation.jl`
核心计算逻辑：
- 惯性-阻尼绑定计算
- 极值惯性估计
- 频率响应计算

#### `inertia_rocof_estimation.jl`
基于频率变化率(ROCOF)的估计：
- 最小惯性估计
- 频率偏差相关约束
- 稳定性检验

#### `frequency_response_analysis.jl`
系统频率响应分析：
- 频率响应特性计算
- 稳定性分析

#### `inertia_damping_fitting.jl`
二次关系拟合：
- 使用GLM进行回归
- 拟合参数 (c, b, a) in c + b*x + a*x²

### 可视化与几何模块

#### `visualization_generator.jl`
2D绘图生成：
- 边界图绘制
- 破轴图(broken-axis plot)
- 交互区域可视化

#### `polyhedra_geometry_3d.jl`
3D几何处理：
- 多面体生成
- 3D顶点计算
- 几何可视化

#### `polygon_visualization_2d.jl`
2D多边形可视化：
- 凸包计算
- 多边形绘制
- 顶点标注

#### `interaction_plot_generation.jl`
交互效应图表：
- 不同参数间的相互作用
- 敏感性分析图表

### 工具模块

#### `workflow_utilities.jl`
工作流支持函数：
- `vertices_to_matrix()` - 矩阵转换
- `write_vertices_to_file()` - 文件写入
- 其他实用函数

#### `environment_config.jl`
环境初始化与兼容性：
- 包包导入和激活
- 全局常数定义（DAMPING_RANGE等）
- 所有模块的include声明
- 向后兼容性包装函数

## 命名规范

### 前缀约定
| 前缀 | 用途 | 示例 |
|------|------|------|
| `run_` | 可执行脚本 | `run_single_droop_analysis.jl` |
| `sys_` | 系统参数相关 | `sys_boundary_parameters.jl` |
| `core_` | 核心计算 | `core_inertia_damping_calculation.jl` |

### 后缀约定
| 后缀 | 含义 | 示例 |
|------|------|------|
| `_calculation` | 数值计算 | `core_inertia_damping_calculation.jl` |
| `_analysis` | 分析处理 | `frequency_response_analysis.jl` |
| `_estimation` | 估计逼近 | `inertia_rocof_estimation.jl` |
| `_fitting` | 曲线拟合 | `inertia_damping_fitting.jl` |
| `_generator` | 生成生成 | `visualization_generator.jl` |
| `_2d/_3d` | 维度标识 | `polygon_visualization_2d.jl` |

## 模块依赖关系

```
环境配置层
    ↓
├─ environment_config.jl (包含所有模块)
│
├─ 架构层
│   ├─ config_structures.jl
│   ├─ validation.jl
│   └─ workflow_orchestrator.jl
│
├─ 计算层
│   ├─ sys_boundary_parameters.jl
│   ├─ converter_config.jl
│   ├─ core_inertia_damping_calculation.jl
│   ├─ inertia_rocof_estimation.jl
│   ├─ frequency_response_analysis.jl
│   └─ inertia_damping_fitting.jl
│
├─ 可视化层
│   ├─ visualization_generator.jl
│   ├─ polyhedra_geometry_3d.jl
│   ├─ polygon_visualization_2d.jl
│   └─ interaction_plot_generation.jl
│
└─ 工具层
    └─ workflow_utilities.jl
```

## 使用指南

### 快速开始
```bash
# 单个参数分析
julia --project=.Pkg/ run_single_droop_analysis.jl

# 批量参数分析
julia --project=.Pkg/ run_batch_droop_analysis.jl
```

### 在Julia REPL中使用
```julia
include("src/environment_config.jl")

# 单个分析
result = execute_workflow(36.0, comp_cfg, controller_cfg)

# 批量处理
droops = collect(range(33, 40; length=20))
plot, vertices = execute_batch_workflow(droops, comp_cfg, controller_cfg)
```

## 向后兼容性

所有现有API保持兼容：
- ✅ `get_inertiatodamping_functions()` - 仍可使用
- ✅ `converter_forming_configurations()` - 正常工作
- ✅ 所有可视化函数 - 完全可用

---

**最后更新**: 2026年4月15日  
**版本**: 2.0 (结构化重命名)
