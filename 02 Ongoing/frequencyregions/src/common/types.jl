"""
    common/types.jl

English: Defines structured configuration objects and state containers for the frequency regions computation.
Chinese: 定义频率安全区域计算的结构化配置对象和状态容器。

This replaces scattered Dict-based configurations with type-safe structs.
通过类型安全的结构体替换了分散的基于 Dict 的配置。
"""

"""
    ControllerConfig

English: Container for controller parameters of Virtual Synchronous Machine (VSM) and Droop control.
Chinese: 虚拟同步发电机 (VSM) 和下垂控制 (Droop) 的控制器参数容器。

# Fields (字段)
- `vsm_params::Dict`: VSM controller parameters (inertia, damping, time_constant)
                      VSM 控制器参数（惯性、阻尼、时间常数）
- `droop_params::Dict`: Droop controller parameters (droop, time_constant)
                        下垂控制器参数（下垂系数、时间常数）
"""
struct ControllerConfig
    vsm_params::Dict
    droop_params::Dict

    function ControllerConfig(vsm_params::Dict, droop_params::Dict)
        # Validation will happen in dedicated validation module
        # 验证将在专门的验证模块中进行
        new(vsm_params, droop_params)
    end
end

"""
    AreaParameters

English: Parameter specifications for a single control area in multi-area analysis.
Chinese: 多区域分析中单个控制区域的参数规范。

# Fields (字段)
- `id::Int`: Unique identifier of the area (区域的唯一标识符)
- `initial_inertia::Float64`: Equivalent initial system inertia H_eq [s] (等效初始系统惯性 H_eq)
- `factorial_coefficient::Float64`: Factorial turbine fraction coefficient K_m (汽轮机原动机系数 K_m)
- `time_constant::Float64`: Governor time constant T_g [s] (调速器时间常数 T_g)
- `droop::Float64`: Governor droop R (expressed as droop = 1/R) (调速器下垂系数 R，表示为 droop = 1/R)
- `rocof_threshold::Float64`: Maximum allowable Rate-of-Change-of-Frequency threshold [Hz/s] (允许的最大频率变化率阈值 ROCOF)
- `nadir_threshold::Float64`: Maximum allowable frequency nadir deviation threshold [Hz] (允许的最大频率最低点偏差阈值 Nadir)
- `power_deviation::Float64`: Power disturbance contingency amplitude ΔP [p.u.] (功率扰动的故障扰动量 ΔP)
"""
struct AreaParameters
    id::Int
    initial_inertia::Float64
    factorial_coefficient::Float64
    time_constant::Float64
    droop::Float64
    rocof_threshold::Float64
    nadir_threshold::Float64
    power_deviation::Float64
end

"""
    TieLine

English: Representation of a tie-line connecting two power areas.
Chinese: 连接两个电力区域的联络线表示。

# Fields (字段)
- `from_area::Int`: Source area ID (源区域 ID)
- `to_area::Int`: Target area ID (目标区域 ID)
- `synchronizing_coeff::Float64`: Synchronizing power coefficient T_12 [p.u.] (整步功率系数 T_12)
- `capacity::Float64`: Maximum transmission capacity limit C_12 [p.u.] (最大输电容量极限 C_12)
"""
struct TieLine
    from_area::Int
    to_area::Int
    synchronizing_coeff::Float64
    capacity::Float64
end

"""
    MultiAreaSystem

English: Definition of a multi-area interconnected power grid.
Chinese: 多区域互联电网的定义。

# Fields (字段)
- `areas::Vector{AreaParameters}`: Vector of parameters for all control areas (所有控制区域参数的向量)
- `tie_lines::Vector{TieLine}`: Vector of all connecting tie-lines (所有连接联络线的向量)
"""
struct MultiAreaSystem
    areas::Vector{AreaParameters}
    tie_lines::Vector{TieLine}
end

"""
    SystemParameters

English: Parameter container representing single-area system boundary conditions and constraints.
Chinese: 代表单区域系统边界条件与约束的参数容器。

# Fields (字段)
- `initial_inertia::Float64`: Initial system inertia [s] (系统初始惯性)
- `factorial_coefficient::Float64`: Factorial coefficient for dynamic models K_m (动态模型的汽轮机系数 K_m)
- `time_constant::Float64`: Governor time constant T_g [s] (调速器时间常数 T_g)
- `droop::Float64`: Damping/governor droop (represented as 1/R) (下垂系数，表示为 1/R)
- `rocof_threshold::Float64`: ROCOF limit [Hz/s] (ROCOF 变化率极限)
- `nadir_threshold::Float64`: Frequency nadir deviation limit [Hz] (频率最低点偏差极限)
- `power_deviation::Float64`: Disturbance magnitude ΔP [p.u.] (扰动幅值 ΔP)
"""
struct SystemParameters
    initial_inertia::Float64
    factorial_coefficient::Float64
    time_constant::Float64
    droop::Float64
    rocof_threshold::Float64
    nadir_threshold::Float64
    power_deviation::Float64
end

"""
    ComputationConfig

English: Computation settings, ranges, and converter model flags.
Chinese: 计算设置、范围以及换流器模型标志。

# Fields (字段)
- `damping_range::AbstractRange`: Range of damping values D to compute (用于计算的阻尼值 D 的范围)
- `min_damping::Float64`: Minimum damping value for output vertex extraction (用于输出顶点提取的最小阻尼值)
- `max_damping::Float64`: Maximum damping value for output vertex extraction (用于输出顶点提取的最大阻尼值)
- `flag_converter::Int64`: Converter type flag (0 = traditional grid-following, 1 = modern grid-forming)
                           换流器类型标志 (0 = 传统跟网型, 1 = 现代构网型)
"""
struct ComputationConfig
    damping_range::AbstractRange
    min_damping::Float64
    max_damping::Float64
    flag_converter::Int64

    function ComputationConfig(damping_range::AbstractRange, min_damping::Float64,
        max_damping::Float64, flag_converter::Int64)
        if min_damping >= max_damping
            throw(ArgumentError("min_damping must be less than max_damping"))
        end
        new(damping_range, min_damping, max_damping, flag_converter)
    end
end

"""
    ComputationResult

English: Container for storing the security boundary result of a specific area.
Chinese: 存储特定区域安全边界计算结果的容器。

# Fields (字段)
- `droop::Float64`: Droop parameter used (使用的下垂系数)
- `plot::Any`: Generated visualization plot object (生成的绘图可视化对象)
- `vertices::Vector`: Computed feasible region vertices (计算得到的安全区域可行点顶点)
- `inertia_bounds::Matrix`: Evaluated upper and lower stability limits (评估得到的惯性上限与下限稳定边界)
- `fitting_parameters::Vector`: Quadratic fitting parameters [c, b, a] for H = c + b*D + a*D^2
                                抛物线拟合参数 [c, b, a]，对应公式 H = c + b*D + a*D^2
"""
struct ComputationResult
    droop::Float64
    plot::Any
    vertices::Vector
    inertia_bounds::Matrix
    fitting_parameters::Vector
end

"""
    WorkflowState

English: Mutable container to maintain runtime states during single-area workflow execution.
Chinese: 维护单区域工作流执行期间运行状态的可变容器。

# Fields (字段)
- `controller_config::ControllerConfig`: Controller parameters (控制器配置)
- `system_params::SystemParameters`: Grid boundary conditions (电网边界条件系统参数)
- `computation_config::ComputationConfig`: Damping ranges and flags (阻尼范围与换流器标志计算配置)
- `inertia_bounds::Any`: Inertia stability limits (惯性稳定边界)
- `extreme_inertia::Any`: Boundary critical inertia values (最低点临界惯性值向量)
- `nadir_vector::Any`: Trapping frequency deviations (频率偏差向量)
- `inertia_vector::Any`: Trapping inertia search values (惯性搜索向量)
- `selected_ids::Any`: Indices of binding constraints (激活约束的索引值)
- `fitting_parameters::Any`: Quadratic curve fit parameters (二次拟合曲线参数)
"""
mutable struct WorkflowState
    controller_config::ControllerConfig
    system_params::SystemParameters
    computation_config::ComputationConfig
    inertia_bounds::Any
    extreme_inertia::Any
    nadir_vector::Any
    inertia_vector::Any
    selected_ids::Any
    fitting_parameters::Any

    function WorkflowState(controller_config::ControllerConfig,
        system_params::SystemParameters,
        computation_config::ComputationConfig)
        new(controller_config, system_params, computation_config,
            nothing, nothing, nothing, nothing, nothing, nothing)
    end
end

# Helper functions for config creation (配置创建的辅助函数)

"""
    create_system_parameters(flag_converter::Int64) -> SystemParameters

English: Instantiates the single-area SystemParameters by loading from configuration defaults.
Chinese: 通过加载默认配置实例化单区域 SystemParameters。

# Arguments (参数)
- `flag_converter::Int64`: Converter type flag (换流器类型标志)

# Returns (返回)
- `SystemParameters`: System parameters struct (系统参数结构体)
"""
function create_system_parameters(flag_converter::Int64)::SystemParameters
    initial_inertia, factorial_coefficient, time_constant, droop,
    rocof_threshold, nadir_threshold, power_deviation = get_parameters(flag_converter)

    return SystemParameters(
        initial_inertia, factorial_coefficient, time_constant, droop,
        rocof_threshold, nadir_threshold, power_deviation
    )
end

"""
    create_computation_config(damping_range::AbstractRange, flag_converter::Int64) -> ComputationConfig

English: Creates a ComputationConfig utilizing the range endpoints as default min/max damping bounds.
Chinese: 创建 ComputationConfig，利用范围端点作为默认的最小/最大阻尼边界。

# Arguments (参数)
- `damping_range::AbstractRange`: Damping range to sweep (扫频阻尼区间范围)
- `flag_converter::Int64`: Converter type flag (换流器类型标志)

# Returns (返回)
- `ComputationConfig`: Config structure (计算配置结构体)
"""
function create_computation_config(damping_range::AbstractRange, flag_converter::Int64)::ComputationConfig
    min_damping = minimum(damping_range)
    max_damping = maximum(damping_range)
    return ComputationConfig(damping_range, min_damping, max_damping, flag_converter)
end

"""
    create_computation_config(damping_range::AbstractRange, min_damping::Float64, 
                             max_damping::Float64, flag_converter::Int64) -> ComputationConfig

English: Creates a ComputationConfig with customized min and max damping limits for output extraction.
Chinese: 创建具有自定义输出提取最小和最大阻尼极限的 ComputationConfig。

# Arguments (参数)
- `damping_range::AbstractRange`: Damping range (阻尼范围)
- `min_damping::Float64`: Minimum damping threshold (最小阻尼阀值)
- `max_damping::Float64`: Maximum damping threshold (最大阻尼阀值)
- `flag_converter::Int64`: Converter type flag (换流器类型标志)

# Returns (返回)
- `ComputationConfig`: Config structure (计算配置结构体)
"""
function create_computation_config(damping_range::AbstractRange, min_damping::Float64,
    max_damping::Float64, flag_converter::Int64)::ComputationConfig
    return ComputationConfig(damping_range, min_damping, max_damping, flag_converter)
end
