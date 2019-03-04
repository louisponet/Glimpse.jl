System{name}(components::T) where {name, T<:Tuple} = System{name, T}(components)
function System{name}(sc::Scene, comp_names::Symbol...) where {name}
	components = component.((sc,), comp_names)
	@assert !any(components .== nothing) "Error, $(names[findall(isequal(nothing), components)]) is not present in the scene yet. TODO add this automatically"
	return System{name}(components)
end

Base.getindex(sys::System, id::Int) = sys.components[id]
Base.getindex(sys::System, id::Symbol) = getfirst(x -> name(x) == id, sys.components)

has_all_components(entity, system) = all(name.(system.components) .∈ (keys(entity.data_ids),))
has_components(entity, names::Symbol...) = all(names .∈ (keys(entity.data_ids),))

abstract type UploaderSystem <: SystemKind     end
struct DefaultUploader       <: UploaderSystem end
struct DepthPeelingUploader  <: UploaderSystem end

# UPLOADER
#TODO we could actually make the uploader system after having defined what kind of rendersystems are there

default_uploader_system(sc::Scene) = System{DefaultUploader}(sc,      :geometry, :default_render)

depth_peeling_uploader_system(sc::Scene) = System{DepthPeelingUploader}(sc, :geometry, :depth_peeling)

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things
#TODO decouple renderpass into some component, or at least the info needed to create the vaos
#TODO Renderpass and rendercomponent carry same name

function update(uploader::System{<: UploaderSystem}, entities::Vector{Entity}, dio::Diorama)
	rendercomp_name = name(uploader.components[2])
	rpid = findfirst(x -> name(x) == rendercomp_name, dio.pipeline)
	if rpid == nothing
		return
	end

	renderpass = dio.pipeline[rpid]

	valid_entities = filter(x -> has_all_components(x, uploader), entities)
	if isempty(valid_entities)
		return
	end
	# println(all(keys(system.components) .∈ (keys(entity.data_ids),)))
	geometry, render = data.(uploader.components)

	instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables

	for entity in valid_entities
		e_render = render[data_id(entity, rendercomp_name)]
		e_geom   = geometry[data_id(entity, :geometry)]

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

default_render_system(sc::Scene) =
	System{DefaultRenderer}(sc,      :default_render,       :spatial, :material, :shape, :point_light, :camera3d)
depth_peeling_render_system(sc::Scene) =
	System{DepthPeelingRenderer}(sc, :depth_peeling_render, :spatial, :material, :shape, :point_light, :camera3d)

#maybe this should be splitted into a couple of systems
function update(renderer::System{DefaultRenderer}, entities::Vector{Entity}, dio::Diorama)

	valid_entities = filter(x -> has_components(x, :default_render, :material, :shape, :spatial), entities)
	if isempty(valid_entities)
		return
	end
	render, spatial, material, shape, light, camera = data.(renderer.components)

	renderpass = getfirst(x -> name(x) == :default_render, dio.pipeline)

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

		e_render   = render[  data_id(entity, :default_render)]
		e_material = material[data_id(entity, :material)]
		e_spatial  = spatial[ data_id(entity, :spatial)]
		e_shape    = shape[   data_id(entity, :shape)]

		mat = translmat(e_spatial.position) * scalemat(Vec3f0(e_shape.scale))
		set_uniform(program, :specpow, e_material.specpow)
		set_uniform(program, :specint, e_material.specint)
		set_uniform(program, :modelmat, mat)
		bind(e_render.vertexarray)
		draw(e_render.vertexarray)
		unbind(e_render.vertexarray)
	end
#TODO light entities, camera entities
end

