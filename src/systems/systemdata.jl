mutable struct SystemData #DT has the components datatypes
	components::Vector{AbstractComponent}
	requested_components # so that new components can be added as well
	singletons::Vector{Singleton}
	engaged ::Bool
	indices ::Vector{Vector{Int}}
	function SystemData(c::Vector{AbstractComponent}, req, singletons::Vector{Singleton}, engaged=true)
		t_ = new(c, req, singletons, engaged, Vector{Int}[])
		return t_
	end
end
function SystemData(dio::Diorama, comp_names::NTuple, singleton_names)
	comps = AbstractComponent[]
	for cn in comp_names
		append!(comps, components(dio, cn))
	end
	singls = Singleton[]
	for sn in singleton_names
		append!(singls, singletons(dio, sn))
	end
	return SystemData(comps, comp_names, singls)
end

isengaged(data::SystemData)  = data.engaged
disengage!(data::SystemData) = data.engaged = false

# Access
function component(sys::SystemData, ::Type{T})::Component{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, Component), sys.components)
	@assert comp != nothing "Component $T not found in system's components"
	return comp
end

function shared_component(sys::SystemData, ::Type{T})::SharedComponent{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), sys.components)
	@assert comp != nothing "SharedComponent $T not found in system's components"
	return comp
end

function Base.getindex(sys::SystemData where Kind, ::Type{T})::T where {T <: Singleton}
	singleton = getfirst(x -> typeof(x) <: T, sys.singletons)
	@assert singleton != nothing "Singleton $T not found in system's singletons"
	return singleton
end

singleton(sys::SystemData, ::Type{T}) where {T <: Singleton}  = sys[T]

function singletons(sys::SystemData, ::Type{T})::Vector{T} where {T <: Singleton}
	singlids = findall(x -> typeof(x) <: T, sys.singletons)
	@assert singlids != nothing "No Singletons of type $T were not found, please add it first"
	return sys.singletons[singlids]
end
singletons(sys::SystemData) = sys.singletons
