module GLider

using GLFW

using GeometryTypes
using ColorTypes
using FixedPointNumbers
using ModernGL
import GLAbstraction: FrameBuffer
include("typedefs.jl")
include("color_utils.jl")
include("canvas.jl")
include("globals.jl")
include("screen.jl")
include("callbacks.jl")
include("shader.jl")
include("program.jl")
export Screen
export destroy!, pollevents, swapbuffers, waitevents, clearcanvas!, resize! 
# package code goes here

end # module
