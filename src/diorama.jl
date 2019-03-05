import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
function Diorama(name::Symbol, screen::Screen; kwargs...) #Defaults
	renderpass = default_renderpass()

    components = [GeometryComponent(1),
  			      DefaultRenderComponent(2),
  			      MaterialComponent(3),
  			      ShapeComponent(4),
		          SpatialComponent(5),
		          PointLightComponent(6),
		          CameraComponent3D(7)]

	dio = Diorama(name, Entity[], components, [renderpass], System[], screen; kwargs...)
	push!(dio.systems, default_uploader_system(dio), default_render_system(dio), sim_system(dio), camera_system(dio))
	return dio
end



#TODO: change such that there are no components until needed?
component(dio::Diorama, ::Type{T}) where {T <: ComponentData} = getfirst(x -> eltype(x) <: T, dio.components)

function center!(dio::Diorama)
    center = zero(Vec3f0)
    for rb in dio.renderables
        modelmat = get(rb.uniforms, :modelmat, Eye4f0())
        center += Vec3f0((modelmat * Vec4f0(0,0,0,1))[1:3]...)
    end
    center /= length(dio.renderables)
    dio.camera.lookat = center
    update!(dio.camera)
end

projmat(dio::Diorama)     = dio.camera.proj
viewmat(dio::Diorama)     = dio.camera.view
projviewmat(dio::Diorama) = dio.camera.projview

"Darken all the lights in the dio by a certain amount"
darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

# component_id(dio::Diorama, name::Symbol) = findfirst( x -> x.name == name, dio.components)
new_entity_data_id(component::Component) = length(component.data) + 1

new_component!(dio::Diorama, component::Component) = push!(dio.components, component)

#TODO handle freeing and reusing stuff
function add_to_components!(datas, components)
	data_ids  = DataID[]
	for (data, comp) in zip(datas, components)
		data_id    = DataID{eltype(comp)}(new_entity_data_id(comp))
		push!(data_ids, data_id)
		push!(comp.data, data)
	end
	return data_ids
end

function new_entity!(dio::Diorama, data...)
	entity_id  = length(dio.entities) + 1

	names      = typeof.(data)
	components = component.((dio, ), names)
	@assert !any(components .== nothing) "Error, $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
	data_ids   = add_to_components!(data, components)
	
	push!(dio.entities, Entity(entity_id, data_ids))
end

# function add_entity_components!(dio::Diorama, entity_id::Int; name_data...)
# 	entity = getfirst(x->x.id == entity_id, dio.entities)
# 	if entity == nothing
# 		error("entity id $entity_id doesn't exist")
# 	end

# 	names      = keys(name_data)
# 	components = component.((dio, ), names)
# 	data_ids   = add_to_components!(values(name_data), components)

# 	append!(data_ids, values(entity.data_ids))
# 	allnames = (keys(entity.data_ids)..., names...)
# 	dio.entities[entity_id] = Entity(entity_id, NamedTuple{allnames}(data_ids))
# end


"""
Clears all the renderables from a dio.
"""
function Base.empty!(dio::Diorama)

    for rb in dio.renderables
        free!(rb)
    end
    empty!(dio.renderables)
    return dio
end
###########
function free!(dio::Diorama)
    free!(dio.screen)
    # free!.(dio.pipeline)
end

function renderloop(dio, framerate = 1/60)
    screen   = dio.screen
    dio    = dio
    while !should_close(dio.screen)
        @time for sys in dio.systems
	        update(sys, dio)
        end
        swapbuffers(dio.screen)

        sleep_pessimistic(framerate - (time()-dio.simdata.time))
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

get_singleton(dio::Diorama, ::Type{T}) where {T <: ComponentData} = getfirst(x -> eltype(x) == T, dio.singletons)
get_renderpass(dio::Diorama, ::Type{T}) where {T <: RenderPassKind} = getfirst(x -> kind(x) == T, dio.singletons)


windowsize(dio::Diorama) = windowsize(dio.screen)

pixelsize(dio::Diorama)  = (windowsize(dio)...,)


# function set!(dio::Diorama, pipeline::Vector{RenderPass}, reupload=true)
    # dio.pipeline = pipeline
    # register_callbacks(pipeline, dio.screen.canvas)
    # dio.reupload = true
# end

# manipulations


# set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.camera.rotation_speed = Float32(rotation_speed)
set_background_color!(dio::Diorama, color) = set_background_color!(dio.screen, color)


# SIMDATA
abstract type SimulationSystem <: SystemKind end
struct Timer <: SimulationSystem end 

sim_system(dio::Diorama) = System{Timer}(dio, Spatial)

#maybe this should be splitted into a couple of systems
function update(renderer::System{Timer}, dio::Diorama)
	sd = dio.simdata
	nt         = time()
	sd.dtime   = nt - sd.time
	sd.time    = time()
	sd.frames += 1
end




# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
