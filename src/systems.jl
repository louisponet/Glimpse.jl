# COnstructors
System{kind}(components::Tuple) where {kind} = System{kind, Tuple{eltype.(components)...}}(components)

function System{kind}(dio::Diorama, comp_names...) where {kind}
	components = component.((dio,), comp_names)
	@assert !any(components .== nothing) "Error, $(components[findall(isequal(nothing), components)]) is not present in the scene yet. TODO add this automatically"
	return System{kind}(components)
end

# Access
Base.getindex(sys::System, id::Int) = sys.components[id]
Base.getindex(sys::System{Kind, TT} where Kind, ::Type{T}) where {TT, T <: ComponentData} =
	sys.components[findfirst(isequal(T), TT.parameters)]

component_types(sys::System{Kind, T} where Kind) where {T<:Tuple} = T.parameters
component_id(sys::System, ::Type{DT}) where {DT<:ComponentData} = findfirst(isequal(DT), component_types(sys))


has_all_components(e::Entity, sys::System) = all(component_types(sys) .∈ (component_types(e),))


has_components(e::Entity, names...) = all(names .∈ (component_types(e),))

abstract type UploaderSystem <: SystemKind     end
struct DefaultUploader       <: UploaderSystem end
struct DepthPeelingUploader  <: UploaderSystem end

# UPLOADER
#TODO we could actually make the uploader system after having defined what kind of rendersystems are there
default_uploader_system(dio::Diorama) = System{DefaultUploader}(dio, Geometry, Render{DefaultPass})

depth_peeling_uploader_system(dio::Diorama) = System{DepthPeelingUploader}(dio, Geometry, Render{DepthPeelingPass})

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things
#TODO decouple renderpass into some component, or at least the info needed to create the vaos
#TODO Renderpass and rendercomponent carry same name

function update(uploader::System{<: UploaderSystem}, dio::Diorama)
	rendercomp_name = kind(eltype(uploader.components[2]))
	renderpass = get_renderpass(dio, rendercomp_name)
	if renderpass == nothing
		return
	end
	valid_entities = filter(x -> has_all_components(x, uploader), dio.entities)
	if isempty(valid_entities)
		return
	end
	geometry, render = data.(uploader.components)

	instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables

	for entity in valid_entities
		e_render = render[data_id(entity, Render{rendercomp_name})]
		e_geom   = geometry[data_id(entity, Geometry)]

		if is_uploaded(e_render)
			continue
		end
		if is_instanced(e_render) # creation of vao needs to be deferred until we have all of them
			if !haskey(instanced_renderables, e_geom.mesh)
				instanced_renderables[e_geom.mesh] = [entity]
			else
				push!(instanced_renderables[e_geom.mesh], entity)
			end
		else
		    e_render.vertexarray = VertexArray(e_geom.mesh, main_program(renderpass))
		end
	end

	#TODO handle instanced_renderables, and uniforms 
	# for (mesh, entities) in instanced_renderables 
	# end
end

abstract type RenderSystem  <: SystemKind   end
struct DefaultRenderer      <: RenderSystem end
struct DepthPeelingRenderer <: RenderSystem end

default_render_system(dio::Diorama) =
	System{DefaultRenderer}(dio, Render{DefaultPass}, Spatial, Material, Shape, PointLight, Camera3D)
depth_peeling_render_system(dio::Diorama) =
	System{DepthPeelingRenderer}(dio, Render{DepthPeelingPass}, Spatial, Material, Shape, PointLight, Camera3D)

#maybe this should be splitted into a couple of systems
function update(renderer::System{DefaultRenderer}, dio::Diorama)

	valid_entities = filter(x -> has_components(x, Render{DefaultPass}, Material, Shape, Spatial), dio.entities)
	if isempty(valid_entities)
		return
	end
	render, spatial, material, shape, light, camera = data.(renderer.components)
	renderpass = get_renderpass(dio, DefaultPass)

	clear!(renderpass.targets[:context])

	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	program = main_program(renderpass)

	bind(program)
    if !isempty(camera)
	    set_uniform(program, :projview, camera[1].projview)
	    set_uniform(program, :campos,   camera[1].eyepos)
    end

    if !isempty(light)
        set_uniform(program, Symbol("plight.color"),              light[1].color)
        set_uniform(program, Symbol("plight.position"),           light[1].position)
        set_uniform(program, Symbol("plight.amb_intensity"),      light[1].ambient)
        set_uniform(program, Symbol("plight.specular_intensity"), light[1].specular)
        set_uniform(program, Symbol("plight.diff_intensity"),     light[1].diffuse)
    end

	for entity in valid_entities

		e_render   = render[  data_id(entity, Render{DefaultPass})]
		e_material = material[data_id(entity, Material)]
		e_spatial  = spatial[ data_id(entity, Spatial)]
		e_shape    = shape[   data_id(entity, Shape)]

		mat = translmat(e_spatial.position) * scalemat(Vec3f0(e_shape.scale))
		set_uniform(program, :specpow, e_material.specpow)
		set_uniform(program, :specint, e_material.specint)
		set_uniform(program, :modelmat, mat)
		bind(e_render.vertexarray)
		draw(e_render.vertexarray)
		GLA.unbind(e_render.vertexarray)
	end
#TODO light entities, camera entities
end

