import GLAbstraction: Shader
import FileIO: load

default_shaders() = [load(joinpath(@__DIR__, "shaders/default.vert")), load(joinpath(@__DIR__, "shaders/default.frag"))]

default_instanced_shaders() = [load(joinpath(@__DIR__, "shaders/default_instanced.vert")), load(joinpath(@__DIR__, "shaders/default_instanced.frag"))]

transparency_shaders() = [load(joinpath(@__DIR__, "shaders/default.vert")), load(joinpath(@__DIR__, "shaders/transparency.frag"))]

peeling_shaders() = [load(joinpath(@__DIR__, "shaders/default.vert")), load(joinpath(@__DIR__, "shaders/peel.frag"))]
peeling_instanced_shaders() = [load(joinpath(@__DIR__, "shaders/default_instanced.vert")),
                               load(joinpath(@__DIR__, "shaders/peel_instanced.frag"))]

compositing_shaders() = [load(joinpath(@__DIR__, "shaders/composite.vert")), load(joinpath(@__DIR__, "shaders/composite.frag"))]

blending_shaders() = [load(joinpath(@__DIR__, "shaders/blend.vert")), load(joinpath(@__DIR__, "shaders/blend.frag"))]
