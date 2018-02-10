using Glimpse

testdiorama = Diorama(interactive=true)

sphere(testdiorama, [0.0,0.0,0.0], 2; color = RGB{Float32}(1,0,0))
sphere(testdiorama, [0.0,0.0,0.0], 2)
add!(testdiorama, Glimpse.PointLight())
testdiorama
empty!(testdiorama)
sizeof(Vec3f0)
free!(testdiorama)

build(testdiorama)

test = GLAbstraction.attributes_info(testdiorama.pipeline.passes[1].program)[1]

bind(testdiorama.scene.renderables[1])
length(eltype(testdiorama.scene.renderables[1].vao)[1].parameters)
