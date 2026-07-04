function mainfun(droop::Real=33.0; save_vertices::Bool=false, output_path::String=OUTPUT_REL_PATH)
    result = execute_workflow(
        Float64(droop),
        create_computation_config(DAMPING_RANGE, MIN_DAMPING, MAX_DAMPING, 0),
        default_controller_config(),
    )

    if save_vertices
        matrix = vertices_to_matrix([result.vertices])
        write_vertices_to_file(matrix, pwd(), output_path)
    end

    return result
end

function get_inertiatodamping_functions(droop_parameters::Real)
    result = mainfun(droop_parameters)
    return result.plot, result.vertices
end
