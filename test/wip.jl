using Glimpse
testdiorama = Diorama()
sphere(testdiorama, [1.0,5.0,-1.0], 2; color = RGB{Float32}(1,0,0))
for i = 1:100
    sphere(testdiorama, [6.0,0.0,0.0], 2)
end
expose(testdiorama);
testdiorama
cylinder(testdiorama, Vec3(1), Vec3(2), 0.2, color= RGB{Float32}(1.0,0,0))
center!(testdiorama.scene)
empty!(testdiorama)
add!(testdiorama, PointLight())
Juno.profiler()
Profile.clear()
testdiorama.loop
