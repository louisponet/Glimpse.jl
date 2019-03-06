# COnstructors
# System{kind}(components::Tuple) where {kind} = System{kind, (eltype.(components)...,)}(components)

function System{kind}(dio::Diorama, comp_names...) where {kind}
	components = component.((dio,), comp_names)
	@assert !any(components .== nothing) "Error, $(components[findall(isequal(nothing), components)]) is not present in the scene yet. TODO add this automatically"
	return System{kind}(components)
end

# Access
Base.getindex(sys::System, id::Int) = sys.components[id]
Base.getindex(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData} =
	sys.components[findfirst(isequal(T), component_types(sys))]


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
	renderpass      = get_renderpass(dio, rendercomp_name)
	if renderpass == nothing
		return
	end

	geometry, render = generate_gapped_arrays(dio, uploader)
	if isempty(geometry)
		return
	end

	instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables
	for (e_render, e_geom) in zip(render, geometry)
		# e_render = render[data_id(entity, Render{rendercomp_name})]
		# e_geom   = geometry[data_id(entity, Geometry)]

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

	render, spatial, material, shape = generate_gapped_arrays(dio, Render{DefaultPass}, Spatial, Material, Shape)
	light, camera = data.(get_components(dio, PointLight, Camera3D))
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

	# @time for (e_render, e_spatial, e_material, e_shape) in zip(render, spatial, material, shape)
	for i=1:length(render)
		e_render = render[i]
		e_material = material[i]
		e_spatial  = spatial[i]
		e_shape = shape[i]
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

