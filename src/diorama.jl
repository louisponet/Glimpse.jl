import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
function Diorama(name::Symbol = :Glimpse; kwargs...) #Defaults
	c                  = Canvas(name; kwargs...)
	wh                 = size(c)
	io_fbo             = RenderTarget{IOTarget}(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background)
	default_pass       = default_renderpass()
	# depth_peeling_pass = create_transparancy_pass(wh, RGBAf0(RGB(c.background),0.0f0), 5)
	depth_peeling_pass = create_transparancy_pass(wh, c.background, 5)
	fp                 = final_pass()
	fullscreenvao      = FullscreenVao()

	timing = TimingData(time(),0.0, 0, 1/60, false)
	dio = Diorama(name, Entity[], AbstractComponent[], [default_pass, depth_peeling_pass, fp, timing, io_fbo, c, fullscreenvao], System[])
    add_component!.((dio,),[PolygonGeometry,
    						FileGeometry,
    						FuncGeometry,
    						FuncColor,
    						BufferColor,
    						Mesh,
		                    Material,
		                    Spatial,
		                    Shape,
		                    UniformColor,
		                    PointLight,
		                    Camera3D,
		                    Dynamic,
		                    ModelMat,
		                    Vao{DefaultProgram},
		                    Vao{PeelingProgram}])
    add_shared_component!.((dio,), [PolygonGeometry,
    								FileGeometry,
    							    Mesh,
							        Vao{DefaultInstancedProgram},
    							    Vao{PeelingInstancedProgram},
    							    RenderProgram{DefaultProgram},
    							    RenderProgram{PeelingProgram},
    							    RenderProgram{DefaultInstancedProgram},
    							    RenderProgram{PeelingInstancedProgram},
    							    Grid])

	add_system!.((dio,),[timer_system(dio),
						 resizer_system(dio),
                         mesher_system(dio),
                         uniform_calculator_system(dio),
			             default_uploader_system(dio),
			             peeling_uploader_system(dio),
			             camera_system(dio),
			             default_render_system(dio),
			             depth_peeling_render_system(dio),
			             final_render_system(dio),
			             sleeper_system(dio)])

	return dio
end


# "Darken all the lights in the dio by a certain amount"
# darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
# lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

function canvas_command(dio::Diorama, command::Function, catchcommand = x -> nothing)
	canvas = singleton(dio, Canvas)
	if canvas != nothing
		command(canvas)
	else
		catchcommand(canvas)
	end
end

function expose(dio::Diorama;  kwargs...)
    if dio.loop == nothing
	    canvas_command(dio, make_current, x -> add_singleton!(dio, Canvas(dio.name; kwargs...))) 
    end
    return dio
end

#TODO move control over this to diorama itself
function renderloop(dio)
    dio    = dio
    canvas_command(dio, canvas ->
	    begin
	    	while !should_close(canvas)
			    clear!(canvas)
			    iofbo = singleton(dio, RenderTarget{IOTarget})
			    bind(iofbo)
			    draw(iofbo)
			    clear!(iofbo)
		        for sys in dio.systems
			        update(sys)
		        end
		        swapbuffers(canvas)
		    end
		    should_close!(canvas, false)
			dio.loop = nothing
		end
	)
end

function reload(dio::Diorama)
	close(dio)
	canvas_command(dio, canvas ->
		begin
			while isopen(canvas) && dio.loop != nothing
				sleep(0.01)
			end
			dio.reupload = true
		    expose(dio)
	    end
    )
end

close(dio::Diorama) = canvas_command(dio, c -> should_close!(c, true))
free!(dio::Diorama) = canvas_command(dio, c -> free!(c))

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end

windowsize(dio::Diorama) = canvas_command(dio, c -> windowsize(c), x -> (0,0))
pixelsize(dio::Diorama)  = (windowsize(dio)...,)
set_background_color!(dio::Diorama, color) = canvas_command(dio, c -> set_background_color!(c, color))


# __/\\\\\\\\\\\\\\\________/\\\\\\\\\_____/\\\\\\\\\\\___        
#  _\/\\\///////////______/\\\////////____/\\\/////////\\\_       
#   _\/\\\_______________/\\\/____________\//\\\______\///__      
#    _\/\\\\\\\\\\\______/\\\_______________\////\\\_________     
#     _\/\\\///////______\/\\\__________________\////\\\______    
#      _\/\\\_____________\//\\\____________________\////\\\___   
#       _\/\\\______________\///\\\___________/\\\______\//\\\__  
#        _\/\\\\\\\\\\\\\\\____\////\\\\\\\\\_\///\\\\\\\\\\\/___ 
#         _\///////////////________\/////////____\///////////_____
  
function Base.empty!(dio::Diorama)
	for component in dio.components
		empty!(component)
	end
	empty!(dio.entities)
end

#TODO: change such that there are no components until needed?
function component(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	for c in components(dio)
		if eltype(c) <: T && isa(c, Component)
			return c
		end
	end
	for c in components(dio)
		if T <: eltype(c) && isa(c, Component)
			return c
		end
	end
end

function shared_component(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	for c in components(dio)
		if eltype(c) <: T && isa(c, SharedComponent)
			return c
		end
	end
	for c in components(dio)
		if T <: eltype(c) && isa(c, SharedComponent)
			return c
		end
	end
end

components(dio::Diorama) = dio.components

function components(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	compids = findall(x -> eltype(x) <: T, dio.components)
	@assert compids != nothing "Component $T was not found, please add it first"
	return dio.components[compids]
end

function singletons(dio::Diorama, ::Type{T}) where {T <: Singleton}
	singlids = findall(x -> typeof(x) <: T, dio.singletons)
	@assert singlids != nothing "No singleton of type $T was not found, please add it first"
	return dio.singletons[singlids]
end

ncomponents(dio::Diorama) = length(dio.components)

singleton(dio::Diorama, ::Type{T}) where {T <: Singleton} = getfirst(x -> isa(x, T), dio.singletons)

function add_component_to_systems(dio, comp::AbstractComponent{T}) where T
	for sys in dio.systems
		for rc in sys.requested_components
			if T <: rc
				push!(sys.components, comp)
				return
			end
		end
	end
end


function add_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	comp = Component(ncomponents(dio)+1, T)
	push!(dio.components, comp)
	add_component_to_systems(dio, comp)
end
	
function add_shared_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	comp = SharedComponent(ncomponents(dio)+1, T)
	push!(dio.components, comp)
	add_component_to_systems(dio, comp)
end

system(dio::Diorama, ::Type{T}) where {T <: SystemKind} =
	getfirst(x -> eltype(x) <: T, dio.systems)

add_system!(dio::Diorama, sys::System) = push!(dio.systems, sys)
function remove_system!(dio::Diorama, ::Type{T}) where {T <: SystemKind}
	sysids = findall(x -> eltype(x) <: T, dio.systems)
	deleteat!(dio.systems, sysids)
end
	

#TODO handle freeing and reusing stuff
#TODO MAKE SURE THAT ALWAYS ALL ENTITIES WITH CERTAIN COMPONENTS THAT SYSTEMS CARE ABOUT IN UNISON ARE SORTED 
function add_to_components!(id, datas, components)
	for (data, comp) in zip(datas, components)
		comp[id] = data
	end
end

function new_entity!(dio::Diorama; separate::Vector{ComponentData}=ComponentData[], shared::Vector{ComponentData}=ComponentData[])
	entity_id  = length(dio.entities) + 1

	names      = typeof.(separate)
	components = component.((dio, ), names)
	shared_names      = typeof.(shared)
	shared_components = shared_component.((dio, ), shared_names)
	@assert !(any(components .== nothing) || any(shared_components .== nothing)) "One or more components in $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
    add_to_components!(entity_id, separate, components)
    add_to_components!(entity_id, shared, shared_components)
	
	push!(dio.entities, Entity(entity_id))
	return entity_id
end

function set_entity_component!(dio::Diorama, entity_id::Int, componentdatas::ComponentData...)
	entity = getfirst(x->x.id == entity_id, dio.entities)
	if entity == nothing
		error("entity id $entity_id doesn't exist")
	end

	for data in componentdatas
		component(dio, typeof(data)).data[entity_id] = data
	end
end



###########
# manipulations
# set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.camera.rotation_speed = Float32(rotation_speed)

function component_ids(dio::Diorama, ComponentTypes)
	diocomps = components(dio)
	ids      = zeros(Int, length(ComponentTypes))
	for (ic, ct) in enumerate(ComponentTypes)
		for c in diocomps
			if eltype(c) == ct
				ids[ic] = c.id
			end
		end
	end
	return ids
end

function get_components(dio::Diorama, component_ids::Vector{Int})
	ncomps   = length(component_ids)
	diocomps = components(dio)
	comps    = Vector{Component}(undef, ncomps)
	for (ic, cid) in enumerate(component_ids)
		for c in diocomps
			if c.id == cid
				comps[ic] = c
			end
		end
	end
	return comps
end

function get_components(dio::Diorama, ComponentTypes::Type{<:ComponentData}...)
	ncomps   = length(ComponentTypes)
	diocomps = components(dio)
	comps    = Vector{Component}(undef, ncomps)
	for (ic, ct) in enumerate(ComponentTypes)
		for c in diocomps
			if eltype(c) == ct
				comps[ic] = c
			end
		end
	end
	return comps
end
#maybe this should be splitted into a couple of systems

component_types(sys::System) = eltype.(sys.components)
component_ids(sys::System)   = [c.id for c in sys.components]
component_id(sys::System, ::Type{DT}) where {DT<:ComponentData} = findfirst(isequal(DT), component_types(sys))

function has_components(e::Entity, components::Vector{<:Component})
	c = 0
	for ct in components
		if has_index(ct.data, e.id)
			c += 1
		end
	end
	return c == length(component_ids)
end



# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
