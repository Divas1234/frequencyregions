module FrequencyRegions

using DataFrames
using DelimitedFiles
using GLM
using LinearAlgebra
using Plots
using Random
using Statistics

include("common/constants.jl")
include("common/system_parameters.jl")
include("common/controller_configurations.jl")
include("common/types.jl")
include("common/validation.jl")
include("common/defaults.jl")
include("common/region_geometry.jl")

include("single_area/inertia_limits.jl")
include("single_area/frequency_response.jl")
include("single_area/analytical_response.jl")
include("single_area/regression.jl")
include("single_area/interaction_plots.jl")
include("single_area/visualization.jl")
include("single_area/workflow.jl")
include("single_area/mainfun.jl")

include("multi_area/topology.jl")
include("multi_area/dynamic_analysis.jl")
include("multi_area/decoupled_workflow.jl")
include("multi_area/visualization.jl")
include("multi_area/mainfun.jl")

const LOAD_OPTIONAL_GEOMETRY = get(ENV, "FREQUENCYREGIONS_LOAD_OPTIONAL_GEOMETRY", "0") == "1"
if LOAD_OPTIONAL_GEOMETRY
    try
        include("common/geometry_export.jl")
    catch e
        @warn "Optional geometry export module could not be loaded" exception = (e, catch_backtrace())
    end
    try
        include("common/polygon_plotting.jl")
    catch e
        @warn "Optional polygon plotting module could not be loaded" exception = (e, catch_backtrace())
    end
end

export DAMPING_RANGE,
       MIN_DAMPING,
       MAX_DAMPING,
       PERCENTAGE_BASE,
       FREQUENCY_BASE,
       OUTPUT_REL_PATH,
       ControllerConfig,
       SystemParameters,
       ComputationConfig,
       ComputationResult,
       WorkflowState,
       AreaParameters,
       TieLine,
       MultiAreaSystem,
       AreaResult,
       ValidationError,
       converter_forming_configurations,
       converter_formming_configuations,
       get_parameters,
       default_controller_config,
       create_system_parameters,
       create_computation_config,
       validate_controller_config,
       validate_system_parameters,
       validate_computation_config,
       validate_inertia_limits,
       validate_computation_results,
       execute_workflow,
       execute_batch_workflow,
       execute_multiarea_workflow,
       run_multiarea_analysis,
       execute_dynamic_multiarea_workflow,
       build_ieee_2area_kundur,
       compute_tie_line_contribution,
       collect_all_vertices,
       print_multiarea_summary,
       write_multiarea_vertices_to_file,
       calculate_fittingparameters,
       calculate_vertex,
       vertices_to_matrix,
       write_vertices_to_file,
       generate_inertia_damping_figure,
       mainfun,
       mainfun_multiarea,
       get_inertiatodamping_functions,
       get_workflow_summary

end
