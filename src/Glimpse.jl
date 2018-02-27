# __precompile__(true)
module Glimpse

using GLFW

using Reexport
@reexport using GeometryTypes
@reexport using ColorTypes
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
include("light.jl")
include("scene.jl")
include("diorama.jl")
include("defaults/renderpass.jl")
include("defaults/pipeline.jl")
include("defaults/shader.jl")
include("defaults/geometries.jl")
#GLAbstraction exports
import GLAbstraction: RenderPass, Pipeline
import GLAbstraction: render, @comp_str, @frag_str, @vert_str, @geom_str,
                      free!

export RenderPass, Pipeline
export render, free!, start
export @comp_str, @frag_str, @vert_str, @geom_str

#package exports, types & enums
export Screen, Scene, Renderable, Camera, Diorama, Area
export pixel, orthographic, perspective

#package exports, functions
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize!,
        draw, current_context, renderloop, add!, build, center!

#package exports, default geometries
export sphere, cylinder, rectangle, cone, arrow

end # module
