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
include("callbacks.jl")
include("screen.jl")
export Screen
# package code goes here

end # module
