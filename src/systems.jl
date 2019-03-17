# COnstructors
# System{kind}(components::Tuple) where {kind} = System{kind, (eltype.(components)...,)}(components)

function System{kind}(dio::Diorama, comp_names, singleton_names) where {kind}
	components = component.((dio,), comp_names)
	singletons = singleton.((dio,), singleton_names)
	@assert !any(components .== nothing) "Error, $(components[findall(isequal(nothing), components)]) is not present in the scene yet. TODO add this automatically"
	return System{kind}(components, singletons)
end

# Access
function Base.getindex(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) == T, sys.components)
	@assert comp != nothing "Component $T not found in system's components"
	return comp
end

function Base.getindex(sys::System{Kind} where Kind, ::Type{T}) where {T <: Singleton}
	singleton = getfirst(x -> eltype(x) == T, sys.singletons)
	@assert singleton != nothing "Singleton $T not found in system's components"
	return singleton
end

abstract type SimulationSystem <: SystemKind end
struct Timer <: SimulationSystem end 

timer_system(dio::Diorama) = System{Timer}(dio, (), (TimingData,))

function update(timer::System{Timer})
	sd = timer.singletons[1]
	nt         = time()
	sd.dtime   = nt - sd.time
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


abstract type UploaderSystem <: SystemKind     end
struct DefaultUploader       <: UploaderSystem end
struct DepthPeelingUploader  <: UploaderSystem end

# UPLOADER
#TODO we could actually make the uploader system after having defined what kind of rendersystems are there
default_uploader_system(dio::Diorama) = System{DefaultUploader}(dio, (Geometry, Render{DefaultPass}), (RenderPass{DefaultPass}))

depth_peeling_uploader_system(dio::Diorama) = System{DepthPeelingUploader}(dio, (Geometry, Render{DepthPeelingPass}),(RenderPass{DepthPeelingPass}))

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things
#TODO decouple renderpass into some component, or at least the info needed to create the vaos
#TODO Renderpass and rendercomponent carry same name

function update(uploader::System{<: UploaderSystem})
	rendercomp_name = eltype(uploader.components[2])
	renderpass      = uploader.singletons[1]

	geometry = uploader[Geometry].data
	render   = uploader[rendercomp_name].data
	if isempty(geometry)
		return
	end
	instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables
	for ir in ranges(render, geometry), i in ir
		e_render = render[i]
		# println(i)
		e_geom   = geometry[i]

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

default_render_system(dio::Diorama) =
	System{DefaultRenderer}(dio, (Render{DefaultPass}, Spatial, Material, Shape, PointLight, Camera3D), (RenderPass{DefaultPass},))

function set_uniform(program, camera::Camera3D)
    set_uniform(program, :projview, camera.projview)
    set_uniform(program, :campos,   camera.eyepos)
end

function set_uniform(program, pointlight::PointLight)
    set_uniform(program, Symbol("plight.color"),              pointlight.color)
    set_uniform(program, Symbol("plight.position"),           pointlight.position)
    set_uniform(program, Symbol("plight.amb_intensity"),      pointlight.ambient)
    set_uniform(program, Symbol("plight.specular_intensity"), pointlight.specular)
    set_uniform(program, Symbol("plight.diff_intensity"),     pointlight.diffuse)
end

#maybe this should be splitted into a couple of systems
function update(renderer::System{DefaultRenderer})
	render     = renderer[Render{DefaultPass}].data
	if isempty(render)
		return
	end

	spatial    = renderer[Spatial].data
	material   = renderer[Material].data
	shape      = renderer[Shape].data
	light      = renderer[PointLight].data
	camera     = renderer[Camera3D].data
	renderpass = renderer.singletons[1]

	clear!(renderpass.targets[:context])

	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	program = main_program(renderpass)

	bind(program)
    if !isempty(camera)
	    set_uniform(program, camera[1])
    end

    if !isempty(light)
		set_uniform(program, light[1])
    end

	ids   = ranges(render, spatial, material, shape)
	for id in ids, i in id
		e_render   = render[i]
		e_material = material[i]
		e_spatial  = spatial[i]
		e_shape    = shape[i]
		mat        = translmat(e_spatial.position) * scalemat(Vec3f0(e_shape.scale))
		set_uniform(program, :specpow, e_material.specpow)
		set_uniform(program, :specint, e_material.specint)
		set_uniform(program, :modelmat, mat)

		GLA.bind(e_render.vertexarray)
		GLA.draw(e_render.vertexarray)
	end
	# GLA.unbind(render[end].vertexarray)
end

struct DepthPeelingRenderer <: RenderSystem end

depth_peeling_render_system(dio::Diorama) =
	System{DepthPeelingRenderer}(dio, (Render{DepthPeelingPass}, Spatial, Material, Shape, PointLight, Camera3D), (RenderPass{DepthPeelingPass},))

function update(renderer::System{DepthPeelingRenderer})
	rp = renderer.singletons[1]
    peeling_program           = main_program(rp)
    peeling_instanced_program = main_instanced_program(rp)
    blending_program    = rp.programs[:blending]
    colorblender        = rp.targets[:colorblender]
    peeling_targets     = [rp.targets[:peel1], rp.targets[:peel2]]
    context_target      = rp.targets[:context]
    compositing_program = rp.programs[:composite]
    fullscreenvao       = context_target.fullscreenvao
    bind(colorblender)
    draw(colorblender)
    clear!(colorblender, context_target.background)
    # glClearBufferfv(GL_COLOR, 0, [0,0,0,1])
    glEnable(GL_DEPTH_TEST)
    canvas_width  = Float32(size(colorblender)[1])
    canvas_height = Float32(size(colorblender)[2])

	render     = renderer[Render{DepthPeelingPass}].data
	spatial    = renderer[Spatial].data
	material   = renderer[Material].data
	shape      = renderer[Shape].data
	light      = renderer[PointLight].data
	camera     = renderer[Camera3D].data
    # function first_pass(renderables, program)
    bind(peeling_program)
    set_uniform(peeling_program, :first_pass, true)
    if !isempty(light)
	    set_uniform(peeling_program, light[1])
    end
    if !isempty(camera)
	    set_uniform(peeling_program, camera[1])
    end
    set_uniform(peeling_program, :canvas_width, canvas_width)
    set_uniform(peeling_program, :canvas_height, canvas_height)

	ids   = ranges(render, spatial, material, shape)
	function renderall()
		for id in ids, i in id
			e_render   = render[i]
			e_material = material[i]
			e_spatial  = spatial[i]
			e_shape    = shape[i]
			mat        = translmat(e_spatial.position) * scalemat(Vec3f0(e_shape.scale))
			set_uniform(peeling_program, :specpow, e_material.specpow)
			set_uniform(peeling_program, :specint, e_material.specint)
			set_uniform(peeling_program, :modelmat, mat)

			GLA.bind(e_render.vertexarray)
			GLA.draw(e_render.vertexarray)
		end
		GLA.unbind(render[end].vertexarray)
	end
	renderall()

    set_uniform(peeling_program, :first_pass, false)
    # end

    # first_pass(rp.renderables, peeling_program)
    # first_pass(instanced_renderables(rp), peeling_instanced_program)

    for layer=1:rp.options.num_passes
        currid = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd =  3 - currid
        prevfbo = layer==1 ? colorblender : peeling_targets[previd]
        glEnable(GL_DEPTH_TEST)
        bind(currfbo)
        draw(currfbo)
        # clear!(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glDisable(GL_BLEND)
        glEnable(GL_DEPTH_TEST)

        bind(peeling_program)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
		renderall()

        # bind(peeling_instanced_program)
        # set_uniform(peeling_instanced_program, :depth_texture, (0, depth_attachment(prevfbo)))
        # render(instanced_renderables(rp), peeling_instanced_program)
        bind(colorblender)
        draw(colorblender)

        glDisable(GL_DEPTH_TEST)
        glEnable(GL_BLEND)
        glBlendEquation(GL_FUNC_ADD)
        glBlendFuncSeparate(GL_DST_ALPHA, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA)

        bind(blending_program)
        set_uniform(blending_program, :color_texture, (0, color_attachment(currfbo, 1)))

        bind(fullscreenvao)
        draw(fullscreenvao)

        glDisable(GL_BLEND)
    end
    bind(compositing_program)
    bind(rp.targets[:context])
    clear!(rp.targets[:context])
    glDrawBuffer(GL_BACK)
    glDisable(GL_DEPTH_TEST)

    set_uniform(compositing_program, :color_texture, (0, color_attachment(colorblender, 1)))
    # set_uniform(compositing_program, :color_texture, (0, color_attachment(peeling_targets[1], 1)))
    bind(fullscreenvao)
    draw(fullscreenvao)
    glFlush()

end
