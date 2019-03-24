# COnstructors
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
function component(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, Component), sys.components)
	# @assert comp != nothing "Component $T not found in system's components"
	return comp
end

function shared_component(sys::System{Kind} where Kind, ::Type{T}) where {T <: ComponentData}
	comp = getfirst(x -> eltype(x) <: T && isa(x, SharedComponent), sys.components)
	# @assert comp != nothing "SharedComponent $T not found in system's components"
	return comp
end

function Base.getindex(sys::System{Kind} where Kind, ::Type{T}) where {T <: Singleton}
	singleton = getfirst(x -> typeof(x) <: T, sys.singletons)
	# @assert singleton != nothing "Singleton $T not found in system's singletons"
	return singleton
end
singleton(sys::System, ::Type{T}) where {T <: Singleton}  = sys[T]

function singletons(sys::System, ::Type{T}) where {T <: Singleton}
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

abstract type UploaderSystem <: SystemKind     end
struct DefaultUploader       <: UploaderSystem end
struct DepthPeelingUploader  <: UploaderSystem end


# UPLOADER
#TODO we could actually make the uploader system after having defined what kind of rendersystems are there
default_uploader_system(dio::Diorama) = System{DefaultUploader}(dio, (Mesh, UniformColor, Upload{DefaultPass}, Vao{DefaultPass}), (RenderPass{DefaultPass},))

depth_peeling_uploader_system(dio::Diorama) = System{DepthPeelingUploader}(dio, (Mesh, UniformColor, Upload{DepthPeelingPass}, Vao{DepthPeelingPass}),(RenderPass{DepthPeelingPass},))

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things
#TODO decouple renderpass into some component, or at least the info needed to create the vaos
#TODO Renderpass and rendercomponent carry same name

function update(uploader::System{<: UploaderSystem})
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	renderpass = singleton(uploader, RenderPass)
	upload     = comp(Upload)
	color      = comp(UniformColor)
	for func in (comp, scomp) 
		mesh = func(Mesh)
		vao  = func(Vao)

		instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables
		for e in valid_entities(upload, mesh)
			eupload = upload[e]
			egeom   = mesh[e]

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
				if has_entity(color, e)
				    vao[e] = Vao{kind(renderpass)}(VertexArray(egeom.mesh, main_program(renderpass), color=color[e].color))
			    else
				    vao[e] = Vao{kind(renderpass)}(VertexArray(egeom.mesh, main_program(renderpass)))
			    end
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
	System{DefaultRenderer}(dio, (Vao{DefaultPass}, Spatial, Material, UniformColor, Shape, PointLight, Camera3D), (RenderPass{DefaultPass}, RenderTarget{IOTarget}))

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
	svao       = scomp(Vao{DefaultPass})
	spatial    = comp(Spatial)
	material   = comp(Material)
	shape      = comp(Shape)
	color      = comp(UniformColor)

	light      = comp(PointLight)
	camera     = comp(Camera3D)
	renderpass = renderer.singletons[1]

	es         = valid_entities(vao, spatial, material, shape, color)
	ses        = valid_entities(svao, spatial, material, shape, color)
	# if isempty(es) && isempty(ses)
	# 	return
	# end

	fbo = singleton(renderer, RenderTarget{IOTarget})
	bind(fbo)
	draw(fbo)
	# glClearDepth(1)
	# glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	program = main_program(renderpass)

	bind(program)
    for i in valid_entities(light)
	    set_uniform(program, light[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(program, spatial[i], camera[i])
    end

	# render all separate vaos
	for e in es
		evao   = vao[e]
		ematerial = material[e]
		espatial  = spatial[e]
		eshape    = shape[e]
		mat        = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
		set_uniform(program, :specpow, ematerial.specpow)
		set_uniform(program, :specint, ematerial.specint)
		set_uniform(program, :modelmat, mat)
		set_uniform(program, :fragcolor, color[e].color)

		GLA.bind(evao.vertexarray)
		GLA.draw(evao.vertexarray)
	end

	# render all shared vaos
	for vao in svao.shared
		GLA.bind(vao.vertexarray)
		for e in shared_entities(svao, vao)
			ematerial = material[e]
			espatial  = spatial[e]
			eshape    = shape[e]
			mat       = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
			set_uniform(program, :specpow, ematerial.specpow)
			set_uniform(program, :specint, ematerial.specint)
			set_uniform(program, :modelmat, mat)
			set_uniform(program, :fragcolor, color[e].color)

			GLA.draw(vao.vertexarray)
		end
	end
	# GLA.unbind(vao[end].vertexarray)
end

rem1(x, y) = (x - 1) % y + 1
struct DepthPeelingRenderer <: RenderSystem end

depth_peeling_render_system(dio::Diorama) =
	System{DepthPeelingRenderer}(dio, (Vao{DepthPeelingPass}, Spatial, Material, Shape, UniformColor, PointLight, Camera3D), (RenderPass{DepthPeelingPass}, RenderTarget{IOTarget}, FullscreenVao))

function update(renderer::System{DepthPeelingRenderer})
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao      = comp(Vao{DepthPeelingPass})
	svao     = scomp(Vao{DepthPeelingPass})
	spatial  = comp(Spatial)
	material = comp(Material)
	shape    = comp(Shape)
	color    = comp(UniformColor)

	light    = comp(PointLight)
	camera   = comp(Camera3D)

	separate_entities  = valid_entities(vao, spatial, material, shape)
	shared_es          = valid_entities(svao, spatial, material, shape)
	# if isempty(separate_entities) && isempty(shared_es)
	# 	return
	# end

	rp = renderer.singletons[1]
    peeling_program           = main_program(rp)
    peeling_instanced_program = main_instanced_program(rp)
    peel_comp_program         = rp.programs[:peel_comp]
    blending_program    = rp.programs[:blending]
    compositing_program = rp.programs[:composite]

    colorblender        = rp.targets[:colorblender]
    peeling_targets     = [rp.targets[:peel1], rp.targets[:peel2]]
    iofbo               = singleton(renderer, RenderTarget{IOTarget})
    fullscreenvao       = singleton(renderer, FullscreenVao)

    bind(colorblender)
    draw(colorblender)
    clear!(colorblender)
    canvas_width  = Float32(size(colorblender)[1])
    canvas_height = Float32(size(colorblender)[2])

	function set_entity_uniforms(i)
		ematerial = material[i]
		espatial  = spatial[i]
		eshape    = shape[i]
		mat        = translmat(espatial.position) * scalemat(Vec3f0(eshape.scale))
		set_uniform(peeling_program, :specpow, ematerial.specpow)
		set_uniform(peeling_program, :specint, ematerial.specint)
		set_uniform(peeling_program, :modelmat, mat)
		set_uniform(peeling_program, :fragcolor, color[i].color)
	end

	function renderall()
		#render all separate ones first
		for i in separate_entities
			evao   = vao[i]
			set_entity_uniforms(i)
			GLA.bind(evao.vertexarray)
			GLA.draw(evao.vertexarray)
		end

		#render all separate ones first
		for evao in svao.shared
			GLA.bind(evao.vertexarray)
			for e in shared_entities(svao, evao)
				set_entity_uniforms(e)
				GLA.draw(evao.vertexarray)
			end
		end
		# GLA.unbind(vao[end].vertexarray)
	end

	# first pass: Render the previous opaque stuff first
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    glDisable(GL_BLEND)

	bind(peel_comp_program)
	set_uniform(peel_comp_program, :first_pass, true)
	set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
	set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
    bind(fullscreenvao)
    draw(fullscreenvao)
	set_uniform(peel_comp_program, :first_pass, false)

	# first pass: Render all the transparent stuff
    bind(peeling_program)
    for i in valid_entities(light)
	    set_uniform(peeling_program, light[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(peeling_program, spatial[i], camera[i])
    end

    set_uniform(peeling_program, :first_pass, true)
    set_uniform(peeling_program, :canvas_width, canvas_width)
    set_uniform(peeling_program, :canvas_height, canvas_height)
	renderall()
    set_uniform(peeling_program, :first_pass, false)

	#start peeling passes
    for layer=1:rp.options.num_passes
        currid  = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd  =  3 - currid
        prevfbo = layer == 1 ? colorblender : peeling_targets[previd]
        bind(currfbo)
        draw(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glEnable(GL_DEPTH_TEST)
        glDisable(GL_BLEND)

		# peel: Render all opaque stuff
		bind(peel_comp_program)
		set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
		set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
		set_uniform(peel_comp_program, :prev_depth,    (2, depth_attachment(prevfbo)))
	    bind(fullscreenvao)
	    draw(fullscreenvao)

		# peel: Render all the transparent stuff
        bind(peeling_program)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
		renderall()


        # bind(peeling_instanced_program)
        # set_uniform(peeling_instanced_program, :depth_texture, (0, depth_attachment(prevfbo)))
        # render(instanced_renderables(rp), peeling_instanced_program)
        
        # blend: push the new peel to the colorblender using correct alphas
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
    end

    bind(iofbo)
    draw(iofbo)
	glDisable(GL_BLEND)

    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(colorblender, 1)))
    bind(fullscreenvao)
    draw(fullscreenvao)
    glFlush()

end

struct FinalRenderer <: RenderSystem end
final_render_system(dio) = System{FinalRenderer}(dio, (), (RenderPass{FinalPass}, Canvas, RenderTarget{IOTarget}, FullscreenVao))

function update(sys::System{FinalRenderer})
    rp                  = singleton(sys, RenderPass{FinalPass})
    compositing_program = main_program(rp)
    canvas              = singleton(sys, Canvas)
    vao                 = singleton(sys, FullscreenVao)
    iofbo               = singleton(sys, RenderTarget{IOTarget})
    bind(canvas)
    draw(canvas)
    clear!(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 1)))
    bind(vao)
    draw(vao)
end


struct Mesher <: SystemKind end
mesher_system(dio) = System{Mesher}(dio, (Geometry, Color, Mesh, Grid), ())

function update(sys::System{Mesher})
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	#setup separate meshes
	polygon = comp(PolygonGeometry)
	file    = comp(FileGeometry)
	mesh    = comp(Mesh)
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)

	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file), (spolygon, sfile)))
		for comp in geomcomps
			for e in valid_entities(comp)
				println(e)
				if has_entity(meshcomp, e)
					continue
				end
				meshcomp[e] = Mesh(BasicMesh(comp[e].geometry))
			end
		end
	end


	funcgeometry  = comp(FuncGeometry)
	if funcgeometry == nothing
		return
	end
	grid          = scomp(Grid)
	funccolor     = comp(FuncColor)
	cycledcolor   = comp(CycledColor)
	for e in valid_entities(funcgeometry, grid)
		if has_entity(mesh, e)
			continue
		end
		values = funcgeometry[e].geometry.(grid[e].points)
		vertices, ids = marching_cubes(values, grid[e].points, funcgeometry[e].iso_value)
		faces = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]

		if cycledcolor != nothing && has_entity(cycledcolor, e)
			# mesh[e] = BasicMesh(
		elseif funccolor != nothing && has_entity(funccolor, e)
			#
		else
			mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
		end
	end

end
		





