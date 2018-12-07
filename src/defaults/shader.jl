import GLAbstraction: Shader
import FileIO: load

default_shaders() = [load(joinpath(@__DIR__, "default.vert")), load(joinpath(@__DIR__, "default.frag"))]

transparency_shaders() = [load(joinpath(@__DIR__, "default.vert")), load(joinpath(@__DIR__, "transparency.frag"))]
