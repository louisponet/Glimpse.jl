import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
function Diorama(name::Symbol, screen::Screen; kwargs...) #Defaults
	renderpass = default_renderpass()
	depth_peeling_pass = create_transparancy_pass((1260, 720), 5)

	dio = Diorama(name, Entity[], AbstractComponent[], [renderpass, depth_peeling_pass, TimingData(time(),0.0, 0, 1/60)], System[], screen; kwargs...)
    add_component!.((dio,),[PolygonGeometry,
    						Mesh,
		                    Material,
		                    Spatial,
		                    Shape,
		                    UniformColor,
		                    PointLight,
		                    Camera3D,
		                    Upload{DefaultPass},
		                    Upload{DepthPeelingPass},
		                    Vao{DefaultPass},
		                    Vao{DepthPeelingPass}])
    add_shared_component!.((dio,), [PolygonGeometry,
    							    Mesh,
							        Vao{DefaultPass},
    							    Vao{DepthPeelingPass}])

	add_system!.((dio,),[timer_system(dio),
                         mesher_system(dio),
			             default_uploader_system(dio),
			             depth_peeling_uploader_system(dio),
			             camera_system(dio),
			             default_render_system(dio),
			             depth_peeling_render_system(dio),
			             sleeper_system(dio)])

	return dio
end


"Darken all the lights in the dio by a certain amount"
darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

function free!(dio::Diorama)
    free!(dio.screen)
    # free!.(dio.pipeline)
end

function renderloop(dio)
    screen = dio.screen
    dio    = dio
    while !should_close(dio.screen)
        for sys in dio.systems
	        update(sys)
        end
        swapbuffers(dio.screen)
    end
    close(dio.screen)
	dio.loop = nothing
    # free!(dio)
end

function reload(dio::Diorama)
	close(dio)
	while isopen(dio.screen) && dio.loop != nothing
		sleep(0.01)
	end
	dio.reupload = true
    expose(dio)
end

function expose(dio::Diorama;  kwargs...)
    if dio.loop == nothing
        dio.screen = dio.screen == nothing ? Screen(dio.name; kwargs...) : raise(dio.screen)
        register_callbacks(dio)
        dio.loop = @async renderloop(dio)
        # dio.loop = renderloop(dio)
    end
    return dio
end

close(dio::Diorama) = should_close!(dio.screen, true)

function register_callbacks(dio::Diorama)
    dio.singletons != nothing && register_callbacks.(filter(x -> isa(x, RenderPass), dio.singletons), (dio.screen.canvas, ))
end

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end

windowsize(dio::Diorama) = windowsize(dio.screen)

pixelsize(dio::Diorama)  = (windowsize(dio)...,)

set_background_color!(dio::Diorama, color) = set_background_color!(dio.screen, color)



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
component(dio::Diorama, ::Type{T}) where {T <: ComponentData} =
	getfirst(x -> eltype(x) <: T && isa(x, Component), dio.components)

shared_component(dio::Diorama, ::Type{T}) where {T <: ComponentData} =
	getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), dio.components)

all_components(dio::Diorama) = dio.components

function all_components(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	compids = findall(x -> eltype(x) <: T, dio.components)
	@assert compids != nothing "Component $T was not found, please add it first"
	return dio.components[compids]
end

ncomponents(dio::Diorama) = length(dio.components)

singleton(dio::Diorama, ::Type{T}) where {T <: Singleton} = getfirst(x -> isa(x, T), dio.singletons)


add_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData} =
	push!(dio.components, Component(ncomponents(dio)+1, T))
	
add_shared_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData} =
	push!(dio.components, SharedComponent(ncomponents(dio)+1, T))

add_system!(dio::Diorama, sys::System) = push!(dio.systems, sys)

#TODO handle freeing and reusing stuff
#TODO MAKE SURE THAT ALWAYS ALL ENTITIES WITH CERTAIN COMPONENTS THAT SYSTEMS CARE ABOUT IN UNISON ARE SORTED 
function add_to_components!(id, datas, components)
	for (data, comp) in zip(datas, components)
		comp[id] = data
	end
end

function new_entity!(dio::Diorama, data...)
	entity_id  = length(dio.entities) + 1

	names      = typeof.(data)
	components = component.((dio, ), names)
	@assert !any(components .== nothing) "One or more components in $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
    add_to_components!(entity_id, data, components)
	
	push!(dio.entities, Entity(entity_id))
	return entity_id
end

function new_shared_entity!(dio::Diorama, separate_data, shared_data)
	entity_id  = length(dio.entities) + 1

	names      = typeof.(separate_data)
	components = component.((dio, ), names)
	shared_names      = typeof.(shared_data)
	shared_components = shared_component.((dio, ), shared_names)
	@assert !(any(components .== nothing) || any(shared_components .== nothing)) "One or more components in $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
    add_to_components!(entity_id, separate_data, components)
    add_to_components!(entity_id, shared_data, shared_components)
	
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

function haszeros(v)
	for i in v
		if iszero(i)
			return true
		end
	end
	return false
end


# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
