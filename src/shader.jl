import GLAbstraction: Shader
import FileIO: load

load_shader_source(source_file) = load(joinpath(@__DIR__, "shaders", source_file))

default_shaders()             = [load_shader_source("default.vert"),
                                 load_shader_source("default.frag")]
default_instanced_shaders()   = [load_shader_source("default_instanced.vert"),
                                 load_shader_source("default_instanced.frag")]

transparency_shaders()        = [load_shader_source("default.vert"),
                                 load_shader_source("transparency.frag")]

peeling_shaders()             = [load_shader_source("default.vert"),
                                 load_shader_source("peel.frag")]
peeling_compositing_shaders() = [load_shader_source("composite.vert"),
                                 load_shader_source("fullscreen_peel.frag")]
peeling_instanced_shaders()   = [load_shader_source("default_instanced.vert"),
                                 load_shader_source("peel_instanced.frag")]

compositing_shaders()         = [load_shader_source("composite.vert"),
                                 load_shader_source("composite.frag")]

blending_shaders()            = [load_shader_source("blend.vert"),
                                 load_shader_source("blend.frag")]


line_shaders()                = [load_shader_source("lines.vert"),
                                 load_shader_source("lines.geom"),
                                 load_shader_source("lines.frag")]

text_shaders()                = [load_shader_source("text.vert"),
                                 load_shader_source("text.frag")]
