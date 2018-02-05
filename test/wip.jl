using Glimpse

testdiorama = Diorama(interactive=true)
testverts = Point3f0.([(-1.0,-1.0,-1.0),(-1.0,-1.0, 1.0),
    (-1.0, 1.0, 1.0),
    (1.0, 1.0,-1.0),
    (-1.0,-1.0,-1.0),
    (-1.0, 1.0,-1.0),
    (1.0,-1.0, 1.0),
    (-1.0,-1.0,-1.0),
    (1.0,-1.0,-1.0),
    (1.0, 1.0,-1.0),
    (1.0,-1.0,-1.0),
    (-1.0,-1.0,-1.0),
    (-1.0,-1.0,-1.0),
    (-1.0, 1.0, 1.0),
    (-1.0, 1.0,-1.0),
    (1.0,-1.0, 1.0),
    (-1.0,-1.0, 1.0),
    (-1.0,-1.0,-1.0),
    (-1.0, 1.0, 1.0),
    (-1.0,-1.0, 1.0),
    (1.0,-1.0, 1.0),
    (1.0, 1.0, 1.0),
    (1.0,-1.0,-1.0),
    (1.0, 1.0,-1.0),
    (1.0,-1.0,-1.0),
    (1.0, 1.0, 1.0),
    (1.0,-1.0, 1.0),
    (1.0, 1.0, 1.0),
    (1.0, 1.0,-1.0),
    (-1.0, 1.0,-1.0),
    (1.0, 1.0, 1.0),
    (-1.0, 1.0,-1.0),
    (-1.0, 1.0, 1.0),
    (1.0, 1.0, 1.0),
    (-1.0, 1.0, 1.0),
    (1.0,-1.0, 1.0)])
testcolors =[rand(RGB{Float32}) for i=1:length(testverts)]
testrenderable = Renderable{3}(1,:test, Dict{Symbol, Any}(:vertices => testverts, :color => testcolors))
add!(testdiorama, testrenderable)

transmat = Glimpse.translmat_y(3.0f0) * Glimpse.scalemat(Vec3f0(1.0, 1.0, 6.0))
testverts2 = [Vec3f0((transmat * Vec4f0(vec...,1.0))[1:3]) for vec in testverts]
testcols2 = [rand(RGB{Float32}) for i=1:length(testverts)]

testrenderable2 = Renderable{3}(1,:test, Dict{Symbol, Any}(:vertices => testverts2, :color => testcols2))
add!(testdiorama, testrenderable2)

cube = HyperRectangle(Vec3f0(0.0f0,.0f0,0.0f0),Vec3f0(1.0f0,1.0f0,50f0))
cube_verts = decompose(Point3f0, cube)
cube_faces = decompose(Face{3,Int32}, cube).-Int32(1)

testcube = Renderable(1,:test, Dict(:vertices =>cube_verts, :color => [rand(RGB) for i = 1:length(cube_verts)],:faces=>cube_faces))
cube2 = HyperRectangle(Vec3f0(0.0f0,.0f0,-1.0f0),Vec3f0(1.0f0,1.0f0,50f0))
cube2_verts = decompose(Point3f0, cube2)
cube2_faces = decompose(Face{3,Int32}, cube2).-Int32(1)

testcube2 = Renderable(1,:test, Dict(:vertices =>cube2_verts, :color => [rand(RGB) for i = 1:length(cube2_verts)],:faces=>cube2_faces))
add!(testdiorama, testcube)
build(testdiorama)
