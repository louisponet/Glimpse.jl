using Glimpse

testdiorama = Diorama(interactive=true, eyepos=Vec3f0(0,-10,0))

sphere(testdiorama, [1.0,5.0,-1.0], 2; color = RGB{Float32}(1,0,0))
sphere(testdiorama, [6.0,0.0,0.0], 2)
println(testdiorama.scene.camera)

c2 = 
