# All Systems are defined in these files
include("systems/core.jl")
include("systems/camera.jl")
include("systems/mesher.jl")

abstract type AbstractRenderSystem  <: System end
include("systems/rendering/prerenderer.jl")
include("systems/rendering/default.jl")
include("systems/rendering/lines.jl")
include("systems/rendering/depthpeeling.jl")
include("systems/rendering/text.jl")
include("systems/rendering/cimgui.jl")
include("systems/rendering/uniforms.jl")
include("systems/rendering/final.jl")
include("systems/rendering/uploading.jl")
include("systems/interaction.jl")
include("systems/editor.jl")

# # various simulation systems
include("systems/simulations.jl")
