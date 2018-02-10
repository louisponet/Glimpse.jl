import GLAbstraction: Shader
import FileIO: load

defaultshaders() = [load(joinpath(@__DIR__, "default.vert")), load(joinpath(@__DIR__, "default.frag"))]
