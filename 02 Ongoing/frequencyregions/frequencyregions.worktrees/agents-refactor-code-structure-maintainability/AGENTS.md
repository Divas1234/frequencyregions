# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Common development commands

- Start Julia in the project and install dependencies
  ```bash
  julia --project=.Pkg/
  ```
  ```julia
  # In the Julia REPL
  julia> using Pkg; Pkg.instantiate()  # one-time per machine
  ```

- Run the main, pre-wired environment and plotting pipeline (recommended entry point)
  ```julia
  # In the Julia REPL started with --project=.Pkg/
  julia> include("src/automatic_workflow.jl")
  julia> p, vertices = get_inertiatodamping_functions(33.0)  # use a Float64 droop value
  ```
  Notes:
  - The environment wiring (packages, constants, includes, plotting backend) is handled via `src/environment_config.jl`, which `automatic_workflow.jl` includes internally.
  - `p` is a composed Plots.jl figure; `vertices` is a vector of (droop, damping, inertia) tuples.

- Persist polygon vertices to `res/all_vertices.txt`
  ```julia
  julia> include("src/automatic_workflow.jl")
  julia> p, vertices = get_inertiatodamping_functions(33.0)
  julia> mat = vertices_to_matrix([vertices])
  julia> write_vertices_to_file(mat, pwd(), "res/all_vertices.txt")
  ```

- Run the standalone example scripts documented in README
  ```julia
  # In the Julia REPL started with --project=.Pkg/
  julia> include("enhanced_mainfunction.jl")
  julia> include(".deb/demo.jl")  # polyhedra visualization demo (uses Makie/Plots deps from the project)
  ```

- Update/refresh dependencies
  ```julia
  # From the Julia REPL with --project=.Pkg/
  julia> using Pkg; Pkg.update()
  ```

- Lint/format
  - No formatter or linter is configured in-repo. If you add one later (e.g., JuliaFormatter.jl, StaticLint.jl), update this file with the exact commands.

- Tests
  - There is no test suite in this repository at present.

## High-level architecture and data flow

- Project environment and wiring (`src/environment_config.jl`)
  - Activates `.Pkg/` (local Julia environment with `Project.toml` and `Manifest.toml`).
  - Imports core packages (Plots, LinearAlgebra, GLM, etc.) and selects the GR backend for Plots (`gr()`).
  - Includes all computational submodules: `boundary.jl`, `inertia_response.jl`, `primary_frequencyresponse.jl`, `analytical_systemfrequencyresponse.jl`, `inertia_damping_regressionrelations.jl`, `visulazations.jl`, `converter_config.jl`, `generate_geometries.jl`, `tem_plot_polygonfigures.jl`.
  - Defines global constants used across modules:
    - `DAMPING_RANGE = 2:0.25:15` and derived `MIN_DAMPING`, `MAX_DAMPING`.
    - `PERCENTAGE_BASE = 100`, `FREQUENCY_BASE = 50`.
    - Output relative path: `res/all_vertices.txt`.

- Orchestrated workflow (`src/automatic_workflow.jl`)
  - `get_inertiatodamping_functions(droop::Float64)` is the main entry point. It:
    1) Reads converter controller parameters via `converter_formming_configuations()` (VSM and Droop controller dicts).
    2) Pulls baseline boundary conditions from `get_parmeters(flag_converter)` in `boundary.jl` (inertia, factorial coefficient, time constant, droop, ROCOF/NADIR thresholds, power deviation). The provided `droop` argument overrides the boundary droop for this run.
    3) Computes feasible inertia bounds and related vectors with `calculate_inertia_parameters(...)` from `primary_frequencyresponse.jl` (calls `inertia_bindings`/`inertia_damping_relations`), and evaluates ROCOF-based limits via `estimate_inertia_limits(...)` (delegates to `min_inertia_estimation` in `inertia_response.jl`).
    4) Fits a quadratic relation between extreme inertia and damping using `calculate_fittingparameters(...)` from `inertia_damping_regressionrelations.jl` (GLM-based regression on [1, damping, damping^2]).
    5) Produces composite plots and a focused subplot via `sub_data_visualization`/`data_visualization` in `visulazations.jl`.
    6) Derives the polygon vertices describing the feasible region with `calculate_vertex(...)` and returns both the plot and the vertices vector.
  - Utility helpers:
    - `vertices_to_matrix(vertices)` flattens vectors of (droop, damping, inertia) tuples into a Float64 matrix.
    - `write_vertices_to_file(mat, base_path, rel_path)` writes rows to `res/all_vertices.txt` (creates the directory if missing).

- Core computation modules
  - `primary_frequencyresponse.jl` — defines `inertia_bindings`, `inertia_damping_relations`, and `calculate_inertia_parameters` which glue together bound computation, extreme inertia selection, and nadir/inertia vector generation.
  - `inertia_response.jl` — ROCOF-based minimum inertia estimation (`min_inertia_estimation`), uses `PERCENTAGE_BASE`/`FREQUENCY_BASE` and vectorized computations for upper bounds over `damping`.
  - `boundary.jl` — centralizes default/baseline parameters and assertions for “traditional” vs “modern” grid modes (selected via `flag_converter`).
  - `inertia_damping_regressionrelations.jl` — small GLM regression to fit a quadratic curve relating damping to extreme inertia.
  - `visulazations.jl` — plot composition utilities, including an improved broken-axis style plot of bounds and interaction regions.
  - `converter_config.jl` — parameter dictionaries for VSM and Droop controllers (inertia, damping, droop, time constants) consumed by the workflow.

- Scripts at repo root
  - `enhanced_mainfunction.jl`, `mainfunction.jl` are stand-alone experiment scripts that rely on the included modules and plotting.
  - `.deb/demo.jl` contains an additional polyhedra visualization demo.

## Environment specifics

- Julia environment is pinned under `.Pkg/` with Julia `1.11.x` recorded in the manifest. Always start Julia with `--project=.Pkg/` for reproducible resolves.
- Plotting uses the GR backend by default (`gr()` in `environment_config.jl`). GLMakie is present in dependencies but not required for the core workflow here.

## Gaps and suggestions for future automation (non-blocking)

- If you introduce a formatter/linter or a test suite, document the exact commands here (e.g., `julia -e 'using Pkg; Pkg.activate(".Pkg/"); using JuliaFormatter; format(".")'`).
- Consider turning the orchestrated workflow into a proper Julia package module (e.g., `FrequencyRegions.jl` with `src/FrequencyRegions.jl` and a `Project.toml` at repo root) to simplify `using`-based entry points.
