import GLAbstraction: Shader
import FileIO: load

default_shaders() = [load(joinpath(@__DIR__, "shaders/default.vert")), load(joinpath(@__DIR__, "shaders/default.frag"))]

transparency_shaders() = [load(joinpath(@__DIR__, "shaders/default.vert")), load(joinpath(@__DIR__, "shaders/transparency.frag"))]
