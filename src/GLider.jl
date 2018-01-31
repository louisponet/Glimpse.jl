module GLider

using GLFW

using GeometryTypes
using ColorTypes
using FixedPointNumbers
using ModernGL
using Quaternions
using GLAbstraction 
import GLAbstraction: FrameBuffer
export RenderPass, Pipeline
export render
include("typedefs.jl")
include("maths/matrices.jl")
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
export Screen, Scene, Renderable, Camera, CamKind
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize!,
       bind, unbind, draw
# package code goes here

end # module
