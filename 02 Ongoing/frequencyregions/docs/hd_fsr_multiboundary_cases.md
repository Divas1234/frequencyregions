# 双区域 H-D 多约束频率安全域算例

Area 1 为受扰区域，Area 2 为未受扰的互联支援区域；基准容量为 100 MVA。
每个图都在 Area 1 的等效阻尼 `D1` 与等效惯性 `H1` 平面中绘制：

- 蓝线：容量钳位动态模型中 `f_nadir = f_min_limit` 的 Nadir 下边界；
- 红线：未钳位动态模型中 `max(abs(P_tie)) = C12` 的联络线功率上边界；
- 黑虚线：初始 ROCOF 下限；
- 绿色阴影：`max(H_nadir, H_rocof) <= H1 <= H_tie` 的交集。

面积由正宽度 `H_tie - max(H_nadir, H_rocof)` 用梯形积分计算。为使未被联络线限制的区域闭合，计算采用 `H1 <= 30 s` 的系统稳定/搜索上限；因此接近该上限的面积是截断面积，而非无限惯性下的物理面积。

## 参数矩阵

| Case | Area 1 调频 | Area 2 调频 | ΔP1 (p.u.) | C12 (p.u.) |
|---|---|---:|---:|---:|
| 1 | 强：Km=0.50, Tg=0.15 s, droop=45 | 强 | 0.35 | 0.20 |
| 2 | 弱：Km=0.12, Tg=0.60 s, droop=15 | 强 | 0.25 | 0.15 |
| 3 | 强：Km=0.50, Tg=0.15 s, droop=45 | 弱 | 0.45 | 0.15 |
| 4 | 弱：Km=0.12, Tg=0.60 s, droop=15 | 弱 | 0.20 | 0.10 |

## 本模型的数值结果

以 `D1=2.5:0.5:12.0`、`H1<=30 s` 计算：

| Case | 可行面积 (p.u.·s) | 活跃边界/交点 |
|---|---:|---|
| 1 | 283.338 | 联络线边界退至 30 s 上限；Nadir 与 ROCOF 宽裕 |
| 2 | 0.000 | 联络线边界约为 0.05 s，低于 Nadir/ROCOF 所需下界；无可行交集 |
| 3 | 282.863 | 联络线边界退至 30 s 上限；本地 Nadir 仅在低 D 侧起作用 |
| 4 | 107.361 | Nadir 与联络线边界交于 `(D1,H1)=(3.841,1.981)` |

Case 2 的零面积是一个重要的可行性结论：在给定 `C12=0.15 p.u.` 下，强支援区的未钳位稳态/暂态潮流已超过容量，而不是仅仅“切掉一部分”安全域。若研究目标必须保留 Case 2 的非空区域，应提高 `C12`，或改变 Area 2 的稳态支援分配；不能在保持此动态模型和这些参数时声称该区域仍有可行解。

Case 4 则真正显示双边界竞争：低阻尼侧由 Nadir 下边界抬升，较高阻尼侧的允许惯性由联络线功率上边界限定，交点标志控制权切换。Case 1 与 Case 3 的联络线约束在本扫描范围未激活，因此其“交点”位于绘图/搜索范围之外。

## 复现

```julia
using FrequencyRegions
results = run_hd_fsr_case_studies()
```

结果图分别输出到 `fig/multi_area/case1_strong_strong/`、
`fig/multi_area/case2_weak_disturbed_strong_healthy/`、
`fig/multi_area/case3_strong_disturbed_weak_healthy/` 与
`fig/multi_area/case4_weak_weak/`。
