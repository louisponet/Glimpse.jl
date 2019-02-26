# __precompile__(true)
module Glimpse
using Reexport
@reexport using GeometryTypes
@reexport using ColorTypes
using FixedPointNumbers
using ModernGL
using Quaternions
using GLAbstraction
const GLA = GLAbstraction

using LinearAlgebra
using GLFW
using Observables
include("extensions.jl")
include("types.jl")
include("utils.jl")
include("maths/matrices.jl")
include("maths/vecmath.jl")
include("color_utils.jl")
include("callbacks.jl")
# include("canvas.jl")
# include("screen.jl")
include("shader.jl")
export default_shaders, default_instanced_shaders, transparency_shaders, peeling_shaders, compositing_shaders,
       peeling_instanced_shaders
# include("camera.jl")
# include("light.jl")
# include("meshes.jl")
# include("renderable.jl")
# include("scene.jl")
# include("renderpass.jl")
# include("diorama.jl")
export windowsize, pixelsize, present
include("geometries.jl")
export sphere, cylinder, rectangle, cone, arrow
#GLAbstraction exports

#package exports, types & enums
export Screen, Scene, MeshRenderable, InstancedMeshRenderable, Camera, Diorama, Area, PointLight, RenderPass, Pipeline
export pixel, orthographic, perspective
export context_renderpass, default_renderpass, windowsize

#package exports, functions
export destroy!, expose, reload
export add!, center!, darken!, lighten!, set_background_color!
        
export translate

#package exports, default geometries

end # module
