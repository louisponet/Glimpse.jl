# __precompile__(true)
module Glimpse
using Reexport
@reexport using GeometryTypes
@reexport using ColorTypes
using FixedPointNumbers
using ModernGL
using Quaternions
using GLAbstraction
using LinearAlgebra
using GLFW
include("typedefs.jl")
include("utils.jl")
include("maths/matrices.jl")
include("maths/vecmath.jl")
include("color_utils.jl")
include("callbacks.jl")
include("canvas.jl")
include("globals.jl")
include("screen.jl")
include("shader.jl")
include("program.jl")
include("camera.jl")
include("light.jl")
include("renderpass.jl")
include("renderable.jl")
include("scene.jl")
include("pipeline.jl")
include("diorama.jl")
include("defaults/defaults.jl")
include("glabstraction_extensions.jl")
#GLAbstraction exports

#package exports, types & enums
export Screen, Scene, Renderable, Camera, Diorama, Area, PointLight, RenderPass, PipeLine
export pixel, orthographic, perspective
export context_renderpass, windowsize

#package exports, functions
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize!,
        draw, current_context, renderloop, add!, expose, center!, darken!

export set_uniforms!



#package exports, default geometries

end # module
