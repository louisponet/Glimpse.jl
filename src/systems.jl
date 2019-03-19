# COnstructors
# System{kind}(components::Tuple) where {kind} = System{kind, (eltype.(components)...,)}(components)

function System{kind}(dio::Diorama, comp_names, singleton_names) where {kind}
	comps = AbstractComponent[]
	for cn in comp_names
		append!(comps, components(dio, cn))
	end
	singletons = singleton.((dio,), singleton_names)
	return System{kind}(comps, singletons)
end

# Access
function component(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, Component), sys.components)
	@assert comp != nothing "Component $T not found in system's components"
	return comp
end

function shared_component(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), sys.components)
	@assert comp != nothing "SharedComponent $T not found in system's components"
	return comp
end

function Base.getindex(sys::System{Kind} where Kind, ::Type{T}) where {T <: Singleton}
	singleton = getfirst(x -> typeof(x) <: T, sys.singletons)
	@assert singleton != nothing "Singleton $T not found in system's singletons"
	return singleton
end
singleton(sys::System, ::Type{T}) where {T <: Singleton} = sys[T]

#DEFAULT SYSTEMS

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
default_uploader_system(dio::Diorama) = System{DefaultUploader}(dio, (Geometry, Upload{DefaultPass}, Vao{DefaultPass}), (RenderPass{DefaultPass}))

depth_peeling_uploader_system(dio::Diorama) = System{DepthPeelingUploader}(dio, (Geometry, Upload{DepthPeelingPass}, Vao{DepthPeelingPass}),(RenderPass{DepthPeelingPass}))

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things
#TODO decouple renderpass into some component, or at least the info needed to create the vaos
#TODO Renderpass and rendercomponent carry same name

function update(uploader::System{<: UploaderSystem})
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	renderpass = singleton(uploader, RenderPass)
	upload     = comp(Upload)
	for func in (comp, scomp) 
		geometry = func(Geometry)
		vao      = func(Vao)

		instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables
		for e in valid_entities(upload, geometry)
			eupload = upload[e]
			# println(i)
			egeom   = geometry[e]

			if has_entity(vao, e)
				continue
			end
			if is_instanced(eupload) # creation of vao needs to be deferred until we have all of them
				if !haskey(instanced_renderables, egeom.mesh)
					instanced_renderables[egeom.mesh] = [entity]
				else
					push!(instanced_renderables[egeom.mesh], entity)
				end
			else
			    vao[e] = Vao{kind(renderpass)}(VertexArray(egeom.mesh, main_program(renderpass)))
			end
		end
	end

	#TODO handle instanced_renderables, and uniforms 
	# for (mesh, entities) in instanced_renderables 
	# end
end

abstract type RenderSystem  <: SystemKind   end
struct DefaultRenderer      <: RenderSystem end

default_render_system(dio::Diorama) =
	System{DefaultRenderer}(dio, (Vao{DefaultPass}, Spatial, Material, Shape, PointLight, Camera3D), (RenderPass{DefaultPass},))

function set_uniform(program, spatial, camera::Camera3D)
    set_uniform(program, :projview, camera.projview)
    set_uniform(program, :campos,   spatial.position)
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
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao        = comp(Vao{DefaultPass})
	spatial    = comp(Spatial)
	material   = comp(Material)
	shape      = comp(Shape)

	light      = comp(PointLight)
	camera     = comp(Camera3D)
	renderpass = renderer.singletons[1]


	clear!(renderpass.targets[:context])

	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	program = main_program(renderpass)

	bind(program)
    for i in valid_entities(light)
	    println(i)
	    set_uniform(program, light[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(program, spatial[i], camera[i])
    end

	# render all separate vaos
	for e in valid_entities(vao, spatial, material, shape)
		evao   = vao[e]
		ematerial = material[e]
		espatial  = spatial[e]
		eshape    = shape[e]
		mat        = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
		set_uniform(program, :specpow, ematerial.specpow)
		set_uniform(program, :specint, ematerial.specint)
		set_uniform(program, :modelmat, mat)

		GLA.bind(evao.vertexarray)
		GLA.draw(evao.vertexarray)
	end

	svao = scomp(Vao{DefaultPass})
	shared_entities = valid_entities(svao, spatial, material, shape)
	for vertexarray in svao.shared
		GLA.bind(vertexarray)
		for e in shared_entities(svao, vertexarray)
			ematerial = material[e]
			espatial  = spatial[e]
			eshape    = shape[e]
			mat        = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
			set_uniform(program, :specpow, ematerial.specpow)
			set_uniform(program, :specint, ematerial.specint)
			set_uniform(program, :modelmat, mat)

			GLA.draw(evao.vertexarray)
		end
	end
	# GLA.unbind(render[end].vertexarray)
end

struct DepthPeelingRenderer <: RenderSystem end

depth_peeling_render_system(dio::Diorama) =
	System{DepthPeelingRenderer}(dio, (Vao{DepthPeelingPass}, Spatial, Material, Shape, PointLight, Camera3D), (RenderPass{DepthPeelingPass},))

function update(renderer::System{DepthPeelingRenderer})
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao      = comp(Vao{DepthPeelingPass})
	spatial  = comp(Spatial)
	material = comp(Material)
	shape    = comp(Shape)
	light    = comp(PointLight)
	camera   = comp(Camera3D)

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

    # function first_pass(renderables, program)
    bind(peeling_program)
    set_uniform(peeling_program, :first_pass, true)

    for i in valid_entities(light)
	    set_uniform(peeling_program, light[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(peeling_program, spatial[i], camera[i])
    end

    set_uniform(peeling_program, :canvas_width, canvas_width)
    set_uniform(peeling_program, :canvas_height, canvas_height)

	sysranges = valid_entities(vao, spatial, material, shape)
	function renderall()
		for i in sysranges
			evao   = vao[i]
			ematerial = material[i]
			espatial  = spatial[i]
			eshape    = shape[i]
			mat        = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
			set_uniform(peeling_program, :specpow, ematerial.specpow)
			set_uniform(peeling_program, :specint, ematerial.specint)
			set_uniform(peeling_program, :modelmat, mat)

			GLA.bind(erender.vertexarray)
			GLA.draw(erender.vertexarray)
		end
		# GLA.unbind(vao[end].vertexarray)
	end
	renderall()

    set_uniform(peeling_program, :first_pass, false)
    # end

    # first_pass(rp.renderables, peeling_program)
    # first_pass(instanced_renderables(rp), peeling_instanced_program)

    for layer=1:rp.options.num_passes
        currid  = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd  =  3 - currid
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
