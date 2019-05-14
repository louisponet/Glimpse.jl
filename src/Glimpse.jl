# __precompile__(true)
module Glimpse
using Reexport
@reexport using GeometryTypes
@reexport using ColorTypes

using AbstractPlotting # I'd like to get away from this
const AP = AbstractPlotting

using ModernGL
using Quaternions
Base.length(::Type{<:RGBA}) = 4
using GLAbstraction
const GLA = GLAbstraction

using LinearAlgebra
using GLFW
using Observables
using Parameters

using CImGui
using CImGui.GLFWBackend
using CImGui.OpenGLBackend
# using TimerOutputs
# const to = TimerOutput()

include("extensions.jl")
include("types.jl")
include("entities.jl")
include("maths/matrices.jl")
include("maths/vecmath.jl")
include("callbacks.jl")
include("shader.jl")
include("geometries.jl")
include("marching_cubes.jl")
export RGBAf0
#GLAbstraction exports


#package exports, types & enums

#package exports, default geometries

end # module
