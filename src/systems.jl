include("systems/rendering.jl")
include("systems/special_systems.jl")
include("systems/camera.jl")

# Constructors
# System{kind}(components::Tuple) where {kind} = System{kind, (eltype.(components)...,)}(components)
function System{kind}(dio::Diorama, comp_names::NTuple, singleton_names) where {kind}
	comps = AbstractComponent[]
	for cn in comp_names
		append!(comps, components(dio, cn))
	end
	singls = Singleton[]
	for sn in singleton_names
		append!(singls, singletons(dio, sn))
	end
	return System{kind}(comps, comp_names, singls)
end

# Access
function component(sys::System{Kind} where Kind, ::Type{T})::Component{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, Component), sys.components)
	@assert comp != nothing "Component $T not found in system's components"
	return comp
end

function shared_component(sys::System{Kind} where Kind, ::Type{T})::SharedComponent{T} where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), sys.components)
	@assert comp != nothing "SharedComponent $T not found in system's components"
	return comp
end

function Base.getindex(sys::System{Kind} where Kind, ::Type{T})::T where {T <: Singleton}
	singleton = getfirst(x -> typeof(x) <: T, sys.singletons)
	@assert singleton != nothing "Singleton $T not found in system's singletons"
	return singleton
end
singleton(sys::System, ::Type{T}) where {T <: Singleton}  = sys[T]

function singletons(sys::System, ::Type{T})::Vector{T} where {T <: Singleton}
	singlids = findall(x -> typeof(x) <: T, sys.singletons)
	@assert singlids != nothing "No Singletons of type $T were not found, please add it first"
	return sys.singletons[singlids]
end

#DEFAULT SYSTEMS
abstract type SimulationSystem <: SystemKind end
struct Timer <: SimulationSystem end 

timer_system(dio::Diorama) = System{Timer}(dio, (), (TimingData,))

function update(timer::System{Timer})
	sd = timer.singletons[1]
	nt         = time()
	sd.dtime   = sd.reversed ? - nt + sd.time : nt - sd.time
	sd.time    = nt
	sd.frames += 1
end

struct Sleeper <: SimulationSystem end 
sleeper_system(dio::Diorama) = System{Sleeper}(dio, (), (TimingData,))

function update(sleeper::System{Sleeper})
	sd         = sleeper.singletons[1]
	curtime    = time()
	sleep_time = sd.preferred_fps - (curtime - sd.time)
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

struct Resizer <: SystemKind end
resizer_system(dio::Diorama) = System{Resizer}(dio, (), (Canvas, RenderTarget{IOTarget}, RenderPass))
function update(sys::System{Resizer})
	c   = singleton(sys, Canvas)
	fwh = callback_value(c, :framebuffer_size)
	resize!(c, fwh)
	resize!(singleton(sys, RenderTarget{IOTarget}).target, fwh)
	for rp in singletons(sys, RenderPass)
		resize_targets(rp, fwh)
	end
end

struct Mesher <: SystemKind end
mesher_system(dio) = System{Mesher}(dio, (Geometry, Color, Mesh, Grid), ())

function update(sys::System{Mesher})
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	#setup separate meshes
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)
	meshed_entities  = valid_entities(mesh)
	smeshed_entities = valid_entities(smesh)

	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file), (spolygon, sfile)))
		for com in geomcomps
			for e in setdiff(valid_entities(com), valid_entities(meshcomp))
				meshcomp[e] = Mesh(BasicMesh(com[e].geometry))
			end
		end
	end

	funcgeometry  = comp(FunctionGeometry)
	densgeometry  = comp(DensityGeometry)
	grid          = scomp(Grid)
	funccolor     = comp(FunctionColor)
	denscolor     = comp(DensityColor)
	# cycledcolor   = comp(CycledColor)
	colorbuffers  = comp(BufferColor)

	meshed_entities = valid_entities(mesh)

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

	for e in setdiff(valid_entities(funcgeometry, grid), meshed_entities)
		values        = funcgeometry[e].geometry.(grid[e].points)
		calc_mesh(values, funcgeometry[e].iso, e)
	end
	for e in setdiff(valid_entities(densgeometry, grid), meshed_entities)
		calc_mesh(densgeometry[e].geometry, densgeometry[e].iso, e)
	end
end

