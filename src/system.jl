include("systems/systemdata.jl")

# Shared System Behavior
isengaged(sys::System)          = isengaged(system_data(sys))
component(sys::System, args...) = component(system_data(sys), args...)

valid_entities(sys::System, comps::Type{<:ComponentData}...) = valid_entities(component.((sys,), comps)...)

shared_component(sys::System, args...) = shared_component(system_data(sys), args...)

Base.getindex(sys::System, args...) = Base.getindex(system_data(sys), args...)

singleton(sys::System, args...) = singleton(system_data(sys), args...)

singletons(sys::System, args...) = singletons(system_data(sys), args...)
singletons(sys::System)          = singletons(system_data(sys))

update(sys::S) where {S<:System} = "Please implement an update method for system $S"

update_indices!(sys::System) = nothing

#default accessor
system_data(sys::System) = sys.data
indices(sys::System) = system_data(sys).indices


# All Systems are defined in these files
include("systems/core.jl")
include("systems/camera.jl")
include("systems/mesher.jl")

abstract type AbstractRenderSystem  <: System end
include("systems/rendering/default.jl")
include("systems/rendering/lines.jl")
include("systems/rendering/depthpeeling.jl")
include("systems/rendering/text.jl")
include("systems/rendering/uniforms.jl")
include("systems/rendering/uploading.jl")
include("systems/rendering/final.jl")

# various simulation systems
include("systems/simulations.jl")
