include("src/environment_config.jl")

using GLMakie

function plot_irregular_polyhedron(vertices, faces)
    """
    Plots a spatially irregular polyhedron using GLMakie.

    Args:
        vertices: A vector of vectors, where each inner vector represents the 
                  (x, y, z) coordinates of a vertex.
        faces: A vector of vectors, where each inner vector represents the 
               indices of the vertices that form a face.
    """

    fig = Figure()
    ax = Axis3(fig[1, 1], aspect = :data, xlabel = "X", ylabel = "Y", zlabel = "Z")

    # Validate input
    if !all(length(v) == 3 for v in vertices)
        error("Each vertex must be a 3-element vector (x, y, z).")
    end
    if !all(all(1 <= i <= length(vertices) for i in face) for face in faces)
        error("Face indices must be within the range of the number of vertices.")
    end
    if !all(length(face) >= 3 for face in faces)
        error("Each face must have at least 3 vertices.")
    end

    # Extract x, y, z coordinates for plotting
    x = [v[1] for v in vertices]
    y = [v[2] for v in vertices]
    z = [v[3] for v in vertices]

    # Plot the vertices as scatter points
    GLMakie.scatter!(ax, x, y, z, color = :blue, markersize = 10)

    # Plot the faces as polygons
    for face in faces
        face_vertices = [vertices[i] for i in face]
        face_x = [v[1] for v in face_vertices]
        face_y = [v[2] for v in face_vertices]
        face_z = [v[3] for v in face_vertices]
        GLMakie.poly!(ax, Point3f.(face_vertices), color = (:skyblue, 0.7), strokecolor = :black, strokewidth = 1)
    end

    # Add labels to the vertices
    for (i, v) in enumerate(vertices)
        GLMakie.text!(ax, string(i), position = Point3f(v...), align = (:center, :baseline), textsize = 20, offset = (0, 0, 15), color = :black)
    end

    display(fig)
    return fig
end

# Example usage with an irregular polyhedron:
vertices_irregular = [
    [0,0,0], [1,0,0], [1,1,0], [0,1,0],  # Bottom square
    [0,0,1], [1,0,1], [1,1,1], [0,1,1]   # Top square
]

faces_irregular = [
    [1,2,3,4],     # Bottom face
    [5,6,7,8],     # Top face
    [1,2,6,5],     # Front face
    [2,3,7,6],     # Right face
    [3,4,8,7],     # Back face
    [4,1,5,8]      # Left face
]

plot_irregular_polyhedron(vertices_irregular, faces_irregular)
