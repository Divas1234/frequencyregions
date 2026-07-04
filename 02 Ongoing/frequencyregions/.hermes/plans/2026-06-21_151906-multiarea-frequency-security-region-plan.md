# 多区域调频安全域项目扩展实现计划

> **For Hermes:** 先按此计划实现；每个代码改动优先补测试，再落实现。

**Goal:** 将现有以单区域惯量-阻尼-下垂分析为核心的研究代码，扩展为一个可运行、可验证、可导出结果的多区域调频安全域项目。

**Architecture:** 保留现有单区域计算链路作为“区域内求解内核”，在其上补全多区域系统建模、区域耦合扰动建模、批量运行入口、结果导出和测试体系。第一阶段采用已存在的 decoupled approximation 作为主路径，先做稳定可用；第二阶段再为更强耦合模型预留接口。

**Tech Stack:** Julia 1.11 / Plots.jl / GLM.jl / Test.jl

---

## 一、当前现状与主要缺口

### 已有基础
- 单区域主流程已存在：`src/workflow_orchestrator.jl`
- 配置与验证框架已存在：`src/config_structures.jl`、`src/validation.jl`
- 多区域雏形已存在：
  - `src/multi_area/network_topology.jl`
  - `src/multi_area/decoupled_workflow.jl`
  - `src/multi_area/multi_area_viz.jl`
  - `src/multi_area/multi_area_runner.jl`

### 主要缺口
1. **还不是一个完整“项目级”多区域入口**：缺少清晰的脚本入口、README 用法、输出约定。
2. **单区域内核仍有 correctness 风险**：尤其是回归拟合、边界校验、可视化硬编码，若不先修正会污染多区域结果。
3. **没有测试体系**：多区域扩展前必须先为单区域与多区域关键路径补最小测试集。
4. **多区域模型能力偏弱**：当前主要是 decoupled approximation，需先把它做成稳定主线，并预留未来 full-coupled 接口。
5. **结果导出与数据结构尚未统一**：单区域顶点、 多区域顶点、图形和摘要结果需要统一 API。

---

## 二、实现范围（建议分两阶段）

### Phase 1：把现有代码扩展为“可交付的多区域项目”
目标：让用户可以直接运行多区域分析、拿到图、顶点文件和摘要结果。

包含：
- 修正单区域内核中的高风险问题
- 稳定多区域 decoupled workflow
- 增加统一入口脚本
- 增加最小测试集
- 更新 README / AGENTS / 使用说明

### Phase 2：增强多区域建模能力
目标：为更真实的区域耦合和网络导入做准备。

包含：
- 为 `import_matpower_case` / `import_psse_raw` 建立明确接口与 stub 行为测试
- 预留 alternative coupling model 接口（不一定本轮实现 full solver）
- 统一 area-level / system-level result schema

---

## 三、建议实施步骤

### 任务 1：先修正单区域内核的 correctness 问题
**Objective:** 避免错误的单区域结果被多区域流程放大。

**Files:**
- Modify: `src/inertia_damping_regressionrelations.jl`
- Modify: `src/primary_frequencyresponse.jl`
- Modify: `src/validation.jl`
- Modify: `src/visulazations.jl`
- Modify: `src/environment_config.jl`

**要做的事：**
1. 修正 GLM 公式，把 `damping^2` 改为显式二次项列名。
2. 修正 `@assert tem[:, 1] > tem[:, 2]` 为逐元素 `all(...)` 检查。
3. 让 `validate_inertia_limits` 正确拒绝空输入。
4. 消除可视化中的硬编码 y 轴范围，改为基于数据动态确定。
5. 统一 `vertices_to_matrix` 的失败语义：优先抛异常，不返回 `nothing`。

**验收：**
- 单区域 workflow 在默认参数下能稳定运行。
- regression fit 的输出长度与数值形态合理。

---

### 任务 2：补齐单区域最小测试集
**Objective:** 在扩展多区域前，给核心内核建立回归保护。

**Files:**
- Create: `test/runtests.jl`
- Create: `test/test_regression_fit.jl`
- Create: `test/test_validation.jl`
- Create: `test/test_vertices.jl`
- Create: `test/test_single_area_workflow.jl`

**测试重点：**
1. `calculate_fittingparameters` 能识别二次关系。
2. `validate_computation_config` / `validate_inertia_limits` 对非法输入抛错。
3. `calculate_vertex` 与 `vertices_to_matrix` 在空输入、单段输入、多段输入下行为稳定。
4. `execute_workflow` 默认配置下返回非空 plot / vertices / fitting parameters。

**验收命令：**
- `julia --project=.Pkg/ -e 'using Test; include("test/runtests.jl")'`

---

### 任务 3：收敛并规范多区域数据结构
**Objective:** 让多区域模块成为单区域内核之上的正式 API，而不是临时拼接。

**Files:**
- Modify: `src/config_structures.jl`
- Modify: `src/multi_area/decoupled_workflow.jl`
- Modify: `src/multi_area/multi_area_runner.jl`
- Modify: `src/multi_area/multi_area_viz.jl`

**要做的事：**
1. 明确 `AreaResult` / system-level result 的字段和类型。
2. 将空结果、失败结果和成功结果区分清楚，避免 `nothing` 混入主流程。
3. 统一多区域顶点导出格式：`area_id, droop, damping, inertia`。
4. 为 `run_multiarea_analysis` 明确稳定返回 schema，并保证无论是否写文件都能返回结果对象。

**验收：**
- REPL 中可稳定调用 `run_multiarea_analysis()`。
- 返回 comparison / overlay / summary / results / all_vertices 五类结果。

---

### 任务 4：补齐多区域测试
**Objective:** 为多区域扩展建立最小可信度。

**Files:**
- Create: `test/test_multiarea_topology.jl`
- Create: `test/test_multiarea_workflow.jl`
- Create: `test/test_multiarea_export.jl`

**测试重点：**
1. `build_ieee_2area_kundur()` 的区域数、联络线数、参数范围。
2. `compute_tie_line_contribution()` 在 `factor=0/0.5/1.0` 下结果正确。
3. `execute_multiarea_workflow()` 返回每个区域的结果。
4. `collect_all_vertices()` / `write_multiarea_vertices_to_file()` 输出维度正确。
5. `run_multiarea_analysis()` 默认配置下可执行并返回非空结果。

---

### 任务 5：增加项目级入口脚本
**Objective:** 让仓库真正变成“多区域调频安全域项目”，而不是只提供库函数。

**Files:**
- Create: `run_multiarea_analysis.jl`
- Optional Modify: `multiarea_main.jl`（若保留则改为 thin wrapper）

**脚本职责：**
1. 加载 `src/environment_config.jl`
2. 调用 `run_multiarea_analysis()`
3. 保存：
   - comparison plot
   - overlay plot
   - summary plot
   - `res/all_vertices_multiarea.txt`
4. 在终端打印简要摘要

**验收命令：**
- `julia --project=.Pkg/ run_multiarea_analysis.jl`

---

### 任务 6：文档化与对外用法整理
**Objective:** 让别人能直接理解并使用多区域项目。

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Optional Modify: `REFACTORING_GUIDE.md`

**要补充的内容：**
1. 单区域 vs 多区域入口说明
2. 默认内置系统（IEEE 2-area）说明
3. decoupled approximation 的物理含义与保守性说明
4. 输出文件说明
5. 测试命令说明
6. 已知限制：MATPOWER/PSS-E 目前仍为 stub/import placeholder

---

## 四、建议修改文件清单

### 核心计算
- `src/inertia_damping_regressionrelations.jl`
- `src/primary_frequencyresponse.jl`
- `src/analytical_systemfrequencyresponse.jl`（若本轮顺手修正 nadir 分支问题）
- `src/validation.jl`
- `src/visulazations.jl`
- `src/environment_config.jl`

### 多区域模块
- `src/config_structures.jl`
- `src/multi_area/network_topology.jl`
- `src/multi_area/decoupled_workflow.jl`
- `src/multi_area/multi_area_viz.jl`
- `src/multi_area/multi_area_runner.jl`

### 脚本与文档
- `run_multiarea_analysis.jl`
- `README.md`
- `AGENTS.md`

### 测试
- `test/runtests.jl`
- `test/test_regression_fit.jl`
- `test/test_validation.jl`
- `test/test_vertices.jl`
- `test/test_single_area_workflow.jl`
- `test/test_multiarea_topology.jl`
- `test/test_multiarea_workflow.jl`
- `test/test_multiarea_export.jl`

---

## 五、验证与交付标准

### 最低交付标准
- 单区域默认 workflow 可运行。
- 多区域默认 workflow 可运行。
- 生成多区域图：comparison / overlay / summary。
- 生成 `res/all_vertices_multiarea.txt`。
- 测试集可运行且通过。
- README 中有明确运行说明。

### 建议验证命令
```bash
julia --project=.Pkg/ -e 'using Test; include("test/runtests.jl")'
julia --project=.Pkg/ mainfunction.jl
julia --project=.Pkg/ enhanced_mainfunction.jl
julia --project=.Pkg/ run_multiarea_analysis.jl
```

---

## 六、风险与取舍

1. **当前多区域模型主要是 decoupled approximation**
   - 优点：实现快、稳定、便于复用单区域内核。
   - 风险：物理保真度有限，需在文档里明确其“保守近似”性质。

2. **单区域内核 bug 若不先修，会污染多区域结果**
   - 所以本计划把 correctness 修正放在最前。

3. **研究代码的绘图与数值逻辑耦合较深**
   - 本轮先保证项目可运行与可测试；后续可再做 deeper modularization。

4. **MATPOWER / PSS-E 导入目前仍是占位**
   - 本轮先保留 stub，但把接口和测试立住。

---

## 七、推荐实施顺序

1. 修正单区域 correctness 问题
2. 建立最小测试框架
3. 稳定多区域 result schema 与 workflow
4. 增加项目级入口脚本
5. 补全多区域测试
6. 更新 README / AGENTS

---

如果你认可，我下一步会按这个计划开始实施，优先做：
**(1) 修正单区域 correctness 问题 + (2) 建立 test/ 最小测试框架**，然后再进入多区域项目化扩展。