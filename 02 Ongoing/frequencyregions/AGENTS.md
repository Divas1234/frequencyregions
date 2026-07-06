# AGENTS.md

This file provides guidance when working with this repository.

## Common Development Commands

- Install or refresh dependencies:
  ```bash
  julia --project=. -e 'using Pkg; Pkg.instantiate()'
  ```

- Load the package:
  ```julia
  using FrequencyRegions
  ```

- Run the single-area frequency-security workflow:
  ```julia
  result = mainfun(33.0)
  result.plot
  result.vertices
  ```

- Run the multi-area frequency-security workflow:
  ```julia
  result = mainfun_multiarea()
  result.dynamic_results
  result.all_vertices
  ```

- Run scripts from the project root:
  ```bash
  julia --project=. scripts/run_single_area.jl
  julia --project=. scripts/run_batch_single_area.jl
  julia --project=. scripts/run_multi_area.jl
  ```

- Run tests:
  ```bash
  julia --project=. test/runtests.jl
  ```

## Source Layout

- `src/FrequencyRegions.jl`
  - Root package module.
  - Owns package imports, include order, and public exports.

- `src/common/`
  - Shared types, constants, validation, controller defaults, system parameters, region geometry, and optional geometry export utilities.

- `src/single_area/`
  - Single-area frequency-security analysis.
  - Entry point: `src/single_area/mainfun.jl`.
  - Workflow orchestration: `src/single_area/workflow.jl`.
  - Core computation files: `frequency_response.jl`, `inertia_limits.jl`, `analytical_response.jl`, `regression.jl`.
  - Plotting files: `visualization.jl`, `interaction_plots.jl`.

- `src/multi_area/`
  - Multi-area frequency-security analysis.
  - Entry point: `src/multi_area/mainfun.jl`.
  - Core files: `topology.jl`, `decoupled_workflow.jl`, `dynamic_analysis.jl`, `visualization.jl`.

## Public Entry Points

- `mainfun(droop::Real=33.0; save_vertices=false, output_path=OUTPUT_REL_PATH)`
  - Main single-area entry point.

- `mainfun_multiarea(; kwargs...)`
  - Main multi-area entry point.

- `get_inertiatodamping_functions(droop)`
  - Legacy-compatible wrapper for single-area analysis.

## Notes

- Use the root `Project.toml` and `Manifest.toml`; the previous `.Pkg/` environment has been removed.
- Do not add new production source files directly under `src/` except `FrequencyRegions.jl`.
- Keep shared code in `src/common/`, single-area code in `src/single_area/`, and multi-area code in `src/multi_area/`.
- Optional geometry modules are loaded only when `FREQUENCYREGIONS_LOAD_OPTIONAL_GEOMETRY=1`.
