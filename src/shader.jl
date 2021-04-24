import GLAbstraction: Shader
import FileIO: load

load_shader(source_file) = Shader(joinpath(@__DIR__, "shaders", source_file))

default_shaders() = [load_shader("default.vert"),
                     load_shader("default.frag")]
instanced_default_shaders() = [load_shader("default_instanced.vert"),
                               load_shader("default_instanced.frag")]

transparency_shaders() = [load_shader("default.vert"),
                          load_shader("transparency.frag")]

peeling_shaders() = [load_shader("default.vert"),
                     load_shader("peel.frag")]
peeling_compositing_shaders() = [load_shader("composite.vert"),
                                 load_shader("fullscreen_peel.frag")]
instanced_peeling_shaders() = [load_shader("default_instanced.vert"),
                               load_shader("peel_instanced.frag")]

compositing_shaders() = [load_shader("composite.vert"),
                         load_shader("composite.frag")]

blending_shaders() = [load_shader("blend.vert"),
                      load_shader("blend.frag")]


line_shaders() = [load_shader("lines.vert"),
                  load_shader("lines.geom"),
                  load_shader("lines.frag")]

fxaa_shaders() = [load_shader("composite.vert"),
                  load_shader("fxaa.frag")]
