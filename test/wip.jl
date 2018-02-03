using GLider
testvista = Vista(interactive=true)
using GeometryTypes
using ColorTypes

cube = HyperRectangle(Vec3f0(0.0f0,0.0f0,1.0f0),Vec3f0(10.0f0,10.0f0,10f0))
cube_verts = decompose(Point3f0, cube)
cube_faces = decompose(Face{3,Int32}, cube).-Int32(1)

testcube = Renderable(1,:test, Dict(:vertices =>cube_verts, :color => [rand(RGB) for i = 1:length(cube_verts)],:faces=>cube_faces))

testrenderable = Renderable{3}(1,:test, Dict(:vertices => Point{2,Float32}[(-0.5, -0.5),
                                                                           ( 0.5, -0.5),
                                                                           ( 0.0,  0.5)],
                                             :color    => [RGB(0.2f0,0.9f0,0.5f0),RGB(0.9f0,0.2f0,0.5f0),RGB(0.5f0,0.2f0,0.9f0)],
                                             :faces => Face{3,Int32}[(0,1,2)]))
testrenderable2 = Renderable{3}(1,:test, Dict(:vertices => Point{2,Float32}[(0.5, 0.5),
                                                                           (-0.5, 0.5),
                                                                           ( 0.0,  -0.5)],
                                             :color    => [RGB(0.2f0,0.9f0,0.5f0),RGB(0.9f0,0.2f0,0.5f0),RGB(0.5f0,0.2f0,0.9f0)]))

add!(testvista, testcube)
testcube.verts.vertices
add!(testvista,testrenderable)
add!(testvista, testrenderable2)
testvista.scene.renderables
GLider.raise(testvista)
testvista.scene.camera.projection = GLider.projmatpersp(45f0, 800f0/600f0, 0.1f0, 100f0)
testvista.scene.camera.view = GLider.lookatmat(Vec3((-3f0, 0f0, -3f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))

testvista.scene.camera
