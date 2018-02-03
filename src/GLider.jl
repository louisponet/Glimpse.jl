# __precompile__(true)
module GLider

using GLFW

using GeometryTypes
using ColorTypes
using FixedPointNumbers
using ModernGL
using Quaternions
using GLAbstraction

include("typedefs.jl")
include("utils.jl")
include("maths/matrices.jl")
include("maths/vecmath.jl")
include("color_utils.jl")
include("canvas.jl")
include("globals.jl")
include("screen.jl")
include("callbacks.jl")
include("shader.jl")
include("program.jl")
include("renderable.jl")
include("camera.jl")
include("scene.jl")
include("vista.jl")
include("defaults/renderpass.jl")
include("defaults/shader.jl")
#GLAbstraction exports
import GLAbstraction: RenderPass, Pipeline
import GLAbstraction: render, @comp_str, @frag_str, @vert_str, @geom_str,
                      free!

export RenderPass, Pipeline
export render, free!
export @comp_str, @frag_str, @vert_str, @geom_str

export Screen, Scene, Renderable, Camera, Vista, Area
export pixel, orthographic, perspective
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize!,
       unbind, draw, current_context, renderloop, add!, raise
# package code goes here

end # module
