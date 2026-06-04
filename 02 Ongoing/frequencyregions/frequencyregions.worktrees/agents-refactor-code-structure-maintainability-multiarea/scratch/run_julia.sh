#!/bin/bash

# Search for julia in common places
JULIA_PATHS=(
    "julia"
    "/usr/local/bin/julia"
    "/opt/homebrew/bin/julia"
    "/Applications/Julia-1.11.app/Contents/Resources/julia/bin/julia"
    "/Applications/Julia-1.10.app/Contents/Resources/julia/bin/julia"
    "/Applications/Julia.app/Contents/Resources/julia/bin/julia"
    "$HOME/.julia/bin/julia"
)

for p in "${JULIA_PATHS[@]}"; do
    if command -v "$p" >/dev/null 2>&1 || [ -f "$p" ]; then
        echo "Found Julia at: $p"
        "$p" --project=.Pkg/ run_multi_area_demo.jl
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            echo "Successfully ran Julia from $p"
            exit 0
        else
            echo "Failed to run Julia from $p (Exit code: $EXIT_CODE)"
        fi
    fi
done

echo "Could not find working Julia executable."
exit 1
