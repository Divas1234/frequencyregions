# FrequencyRegions

FrequencyRegions is a Julia package for computing and visualizing frequency-security regions in power systems. It focuses on inertia, damping, droop, RoCoF limits, nadir-related bounds, and multi-area frequency response workflows.

## Project Layout

```text
.
├── Project.toml
├── Manifest.toml
├── src/
│   ├── FrequencyRegions.jl
│   ├── constants.jl
│   ├── entrypoints.jl
│   ├── region_geometry.jl
│   └── multi_area/
├── test/
├── scripts/
├── examples/
├── docs/
├── fig/
└── res/
```

## Setup

Install dependencies from the project root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Load the package:

```julia
using FrequencyRegions
```

## Main Entry Points

Single-area workflow:

```julia
result = mainfun(33.0)
result.plot
result.vertices
```

Multi-area workflow:

```julia
result = mainfun_multiarea()
result.dynamic_results
result.all_vertices
```

Legacy compatibility is preserved:

```julia
p, vertices = get_inertiatodamping_functions(33.0)
```

## Scripts

Run the standard workflows from the project root:

```bash
julia --project=. scripts/run_single_area.jl
julia --project=. scripts/run_batch_single_area.jl
julia --project=. scripts/run_multi_area.jl
```

Generate the support-set demo:

```bash
julia --project=. examples/inertia_damping_supportset_demo.jl
```

Plot exported polyhedra with Python after generating `res/single_area/all_vertices.txt`:

```bash
python scripts/plot_polyhedra.py
```

## Tests

```bash
julia --project=. test/runtests.jl
```

## Notes

Optional geometry and polygon plotting files are not loaded by default. Set the environment variable below before loading the package if you need those optional modules:

```bash
FREQUENCYREGIONS_LOAD_OPTIONAL_GEOMETRY=1 julia --project=.
```
