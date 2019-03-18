import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
function Diorama(name::Symbol, screen::Screen; kwargs...) #Defaults
	renderpass = default_renderpass()
	depth_peeling_pass = create_transparancy_pass((1260, 720), 5)
    components = [GeometryComponent(1),
  			      DefaultRenderComponent(2),
  			      MaterialComponent(3),
  			      ShapeComponent(4),
		          SpatialComponent(5),
		          PointLightComponent(6),
		          CameraComponent3D(7),
		          DepthPeelingRenderComponent(8),
		          ]

	dio = Diorama(name, Entity[], components, [renderpass, depth_peeling_pass, TimingData(time(),0.0, 0, 1/60)], System[], screen; kwargs...)
	push!(dio.systems, timer_system(dio), default_uploader_system(dio), depth_peeling_uploader_system(dio), camera_system(dio), default_render_system(dio), depth_peeling_render_system(dio), sleeper_system(dio))
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
component(dio::Diorama, ::Type{T}) where {T <: ComponentData} = getfirst(x -> eltype(x) <: T, dio.components)
singleton(dio::Diorama, ::Type{T}) where {T <: Singleton}     = getfirst(x -> isa(x, T),      dio.singletons)
ncomponents(dio::Diorama) = length(dio.components)

add_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData} =
	push!(dio.components, Component(ncomponents(dio)+1, T))

add_system!(dio::Diorama, sys::System) = push!(dio.systems, sys)

#TODO handle freeing and reusing stuff
#TODO MAKE SURE THAT ALWAYS ALL ENTITIES WITH CERTAIN COMPONENTS THAT SYSTEMS CARE ABOUT IN UNISON ARE SORTED 
function add_to_components!(id, datas, components)
	for (data, comp) in zip(datas, components)
		comp.data[id] = data
	end
end

function new_entity!(dio::Diorama, data...)
	entity_id  = length(dio.entities) + 1

	names      = typeof.(data)
	components = component.((dio, ), names)
	@assert !any(components .== nothing) "Error, $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
    add_to_components!(entity_id, data, components)
	
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
components(dio::Diorama) = dio.components
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

has_components(e::Entity, sys::System) = has_components(e, components(sys))

get_valid_entities(dio::Diorama, ComponentTypes...) = filter(x -> has_components(x, get_components(dio::Diorama, ComponentTypes)), dio.entities)

function haszeros(v)
	for i in v
		if iszero(i)
			return true
		end
	end
	return false
end

function generate_gapped_arrays(dio::Diorama, ComponentTypes::Type{<:ComponentData}...)
	cids = component_ids(dio, ComponentTypes)
	@assert !haszeros(cids) "Not all components required by the system were found"
	
	valid_ids = [Int[] for i = 1:length(cids)]
	for entity in dio.entities
		if !has_components(entity, cids)
			continue
		end
		for (ic, cid) in enumerate(cids)
			push!(valid_ids[ic], data_id(entity, cid))
		end
	end
	#TODO SCARY WATCHOUT!!!!!!! should we do this?
	sort!.(valid_ids)
	gaps = [Gap[] for i=1:length(ComponentTypes)]
	for (ic, vids) in enumerate(valid_ids)
		for i = 1:2:length(vids)
			gap = vids[i+1] - vids[i] 
			if gap != 1
				push!(gaps[ic], Gap(vids[i] + 1, gap))
			end
		end
	end
	components = get_components(dio, cids)
	arrs = [GappedArray(component.data, gap) for (component, gap) in zip(components,gaps)]
	return arrs
end

generate_gapped_arrays(dio::Diorama, sys::System{<:SystemKind})  =
	generate_gapped_arrays(dio, component_types(sys)...)


# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
