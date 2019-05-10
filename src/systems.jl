include("systems/rendering.jl")
include("systems/special_systems.jl")
include("systems/camera.jl")

# Constructors
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

isengaged(data::SystemData) = data.engaged

isengaged(sys::System) = isengaged(system_data(sys))

# Access
function component(sys::SystemData, ::Type{T})::Component{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, Component), sys.components)
	@assert comp != nothing "Component $T not found in system's components"
	return comp
end
component(sys::System, args...) = component(system_data(sys), args...)

valid_entities(sys::System, comps::Type{<:ComponentData}...) = valid_entities(component.((sys,), comps)...)

function shared_component(sys::SystemData, ::Type{T})::SharedComponent{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), sys.components)
	@assert comp != nothing "SharedComponent $T not found in system's components"
	return comp
end
shared_component(sys::System, args...) = shared_component(system_data(sys), args...)

function Base.getindex(sys::SystemData where Kind, ::Type{T})::T where {T <: Singleton}
	singleton = getfirst(x -> typeof(x) <: T, sys.singletons)
	@assert singleton != nothing "Singleton $T not found in system's singletons"
	return singleton
end
Base.getindex(sys::System, args...) = Base.getindex(system_data(sys), args...)

singleton(sys::SystemData, ::Type{T}) where {T <: Singleton}  = sys[T]
singleton(sys::System, args...) = singleton(system_data(sys), args...)

function singletons(sys::SystemData, ::Type{T})::Vector{T} where {T <: Singleton}
	singlids = findall(x -> typeof(x) <: T, sys.singletons)
	@assert singlids != nothing "No Singletons of type $T were not found, please add it first"
	return sys.singletons[singlids]
end
singletons(sys::SystemData) = sys.singletons
singletons(sys::System, args...) = singletons(system_data(sys), args...)
singletons(sys::System) = singletons(system_data(sys))

update(sys::S) where {S<:System} = "Please implement an update method for system $S"

update_indices!(sys::System) = nothing

#default accessor
system_data(sys::System) = sys.data

#DEFAULT SYSTEMS
indices(sys::System) = system_data(sys).indices

abstract type SimulationSystem <: System end
struct Timer <: SimulationSystem
	data ::SystemData

	Timer(dio::Diorama) = new(SystemData(dio, (), (TimingData,)))
end 

function update(timer::Timer)
	sd = system_data(timer).singletons[1]
	nt         = time()
	sd.dtime   = sd.reversed ? - nt + sd.time : nt - sd.time
	sd.time    = nt
	sd.frames += 1
end

struct Sleeper <: SimulationSystem
	data ::SystemData

	Sleeper(dio::Diorama) = new(SystemData(dio, (), (TimingData, Canvas)))
end 

function update(sleeper::Sleeper)
	swapbuffers(singleton(sleeper, Canvas))
	sd         = singletons(sleeper)[1]
	curtime    = time()
	sleep_time = sd.preferred_fps - (curtime - sd.time)
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

struct Resizer <: System
	data ::SystemData

	Resizer(dio::Diorama) = new(SystemData(dio, (), (Canvas, RenderTarget)))
end

function update(sys::Resizer)
	c   = singleton(sys, Canvas)
	fwh = callback_value(c, :framebuffer_size)
	resize!(c, fwh)
	for rt in singletons(sys, RenderTarget)
		resize!(rt, fwh)
	end
end

struct Mesher <: System
	data ::SystemData

	Mesher(dio::Diorama) = new(SystemData(dio, (Geometry, Color, Mesh, Grid), ()))
end

function update_indices!(sys::Mesher)
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)
	meshed_entities  = valid_entities(mesh)
	funcgeometry     = comp(FunctionGeometry)
	densgeometry     = comp(DensityGeometry)
	grid             = scomp(Grid)
	vgeom            = comp(VectorGeometry)
	# cycledcolor   = comp(CycledColor)
	tids = Vector{Int}[]
	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file, vgeom), (spolygon, sfile)))
		for com in geomcomps
			push!(tids, setdiff(valid_entities(com), valid_entities(meshcomp)))
		end
	end
	sys.data.indices = [tids; [setdiff(valid_entities(funcgeometry, grid), meshed_entities),
	                           setdiff(valid_entities(densgeometry, grid), meshed_entities)]]
 end

function update(sys::Mesher)
	if all(isempty.(indices(sys)))
		return
	end
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	#setup separate meshes
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)

	vgeom    = comp(VectorGeometry)
	id_counter = 1
	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file, vgeom), (spolygon, sfile)))
		for com in geomcomps
			for e in indices(sys)[id_counter]
				meshcomp[e] = Mesh(BasicMesh(com[e].geometry))
			end
			id_counter += 1
		end
	end

	funcgeometry  = comp(FunctionGeometry)
	densgeometry  = comp(DensityGeometry)
	grid          = scomp(Grid)
	funccolor     = comp(FunctionColor)
	denscolor     = comp(DensityColor)
	# cycledcolor   = comp(CycledColor)
	colorbuffers  = comp(BufferColor)

	function calc_mesh(density, iso, e)
		vertices, ids = marching_cubes(density, grid[e].points, iso)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
		# if has_entity(cycledcolor, e)
		if has_entity(funccolor, e)
			colorbuffers[e] = BufferColor(funccolor[e].color.(vertices))
		elseif has_entity(denscolor, e)
			colorbuffers[e] = BufferColor([denscolor[e].color[i...] for i in ids])
		end
		mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end

	for e in indices(sys)[id_counter] 
		values        = funcgeometry[e].geometry.(grid[e].points)
		calc_mesh(values, funcgeometry[e].iso, e)
		id_counter += 1
	end

	for e in indices(sys)[id_counter]
		calc_mesh(densgeometry[e].geometry, densgeometry[e].iso, e)
	end
end

