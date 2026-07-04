@testset "vertex matrix conversion" begin
    verts = [
        [(33.0, 2.0, 8.0), (33.0, 3.0, 9.0)],
        [(34.0, 2.5, 10.0)]
    ]

    mat = vertices_to_matrix(verts)

    @test size(mat) == (3, 3)
    @test mat[1, :] == [33.0, 2.0, 8.0]
    @test mat[3, :] == [34.0, 2.5, 10.0]

    empty_mat = vertices_to_matrix(Any[])
    @test size(empty_mat) == (0, 3)
end
