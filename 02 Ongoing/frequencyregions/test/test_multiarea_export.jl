@testset "multi-area export" begin
    tmpdir = mktempdir()
    outfile = joinpath(tmpdir, "all_vertices_multiarea.txt")
    vertices = [
        1.0 33.0 2.5 8.5
        2.0 33.0 2.5 9.0
    ]

    write_multiarea_vertices_to_file(vertices, pwd(), outfile)

    @test isfile(outfile)
    content = read(outfile, String)
    @test occursin("# area_id\tdroop\tdamping\tinertia", content)
    @test occursin("1.0\t33.0\t2.5\t8.5", content)
end
