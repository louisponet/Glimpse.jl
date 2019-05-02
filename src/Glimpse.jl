# __precompile__(true)
module Glimpse
using Reexport
@reexport using GeometryTypes
@reexport using ColorTypes
using FixedPointNumbers
using ModernGL
using Quaternions
Base.length(::Type{<:RGBA}) = 4
using GLAbstraction
const GLA = GLAbstraction

using LinearAlgebra
using GLFW
using Observables
@reexport using Setfield

# using TimerOutputs
# const to = TimerOutput()

include("extensions.jl")
include("types.jl")
include("entities.jl")
include("systems.jl")
include("utils.jl")
include("color_utils.jl")
include("maths/matrices.jl")
include("maths/vecmath.jl")
include("callbacks.jl")
include("shader.jl")
export default_shaders, default_instanced_shaders, transparency_shaders, peeling_shaders, compositing_shaders,
       peeling_instanced_shaders
export windowsize, pixelsize, present
include("geometries.jl")
include("marching_cubes.jl")
export RGBAf0
#GLAbstraction exports


#package exports, types & enums
export Screen, Scene, MeshRenderable, InstancedMeshRenderable, Camera, Diorama, Area, PointLight, RenderPass, Pipeline
export pixel, orthographic, perspective
export context_renderpass, default_renderpass, windowsize

#package exports, functions
export destroy!, expose, reload, close
export add!, center!, darken!, lighten!, set_background_color!
        
export translate

#package exports, default geometries

end # module
