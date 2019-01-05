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
using Observables
include("extensions.jl")
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
export default_shaders, transparency_shaders, peeling_shaders, compositing_shaders
include("program.jl")
include("camera.jl")
include("light.jl")
include("renderable.jl")
include("scene.jl")
include("renderpass.jl")
include("diorama.jl")
export windowsize, pixelsize
include("geometries.jl")
export sphere, cylinder, rectangle, cone, arrow
#GLAbstraction exports

#package exports, types & enums
export Screen, Scene, Renderable, Camera, Diorama, Area, PointLight, Renderpass, Pipeline
export pixel, orthographic, perspective
export context_renderpass, windowsize

#package exports, functions
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize!,
        draw, current_context, renderloop, add!, expose, center!, darken!,
        destroy_current_context

export set_uniforms!



#package exports, default geometries

end # module
