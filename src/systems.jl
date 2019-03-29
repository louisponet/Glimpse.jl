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

struct UniformCalculator <: SystemKind end
uniform_calculator_system(dio::Diorama) = System{UniformCalculator}(dio, (Spatial, Shape, ModelMat, Dynamic), ())
function update(sys::System{UniformCalculator})
	comp(T) = component(sys, T) 
	spatial  = comp(Spatial)
	shape    = comp(Shape)
	dyn      = comp(Dynamic)
	modelmat = comp(ModelMat)
	
	dynamic_entities = valid_entities(dyn)
	already_filled    = valid_entities(modelmat)
	es               = valid_entities(spatial, shape)
	for e in setdiff(es, already_filled)	 
		modelmat[e] = ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale)))
	end
	
	for e in es ∩ dynamic_entities
		overwrite!(modelmat, ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale))), e)
	end
end

struct DefaultProgram          <: ProgramKind end
struct DefaultInstancedProgram <: ProgramKind end
struct PeelingCompositeProgram <: ProgramKind end
struct PeelingProgram          <: ProgramKind end
struct PeelingInstancedProgram <: ProgramKind end

function set_entity_uniforms_func(render_program::RenderProgram{<:Union{DefaultProgram, PeelingProgram}}, system)
    prog = render_program.program
    material = component(system, Material)
    modelmat = component(system, ModelMat)
    ucolor   = component(system, UniformColor)
	return e -> begin
		set_uniform(prog, :specint, material[e].specint)
		set_uniform(prog, :specpow, material[e].specpow)
		set_uniform(prog, :modelmat, modelmat[e].modelmat)
		if has_entity(ucolor, e)
			set_uniform(prog, :uniform_color, ucolor[e].color)
			set_uniform(prog, :is_uniform, true)
		else
			set_uniform(prog, :is_uniform, false)
			set_uniform(prog, :specpow, material[e].specpow)
		end
	end
end

struct Uploader{P <: ProgramKind} <: SystemKind end
	

default_uploader_system(dio::Diorama) =
	System{Uploader{DefaultProgram}}(dio, (Mesh,
										   BufferColor,
								      	   Vao{DefaultProgram},
								      	   ProgramTag{DefaultProgram},
								      	   ), (RenderProgram{DefaultProgram},))

peeling_uploader_system(dio::Diorama) =
	System{Uploader{PeelingProgram}}(dio, (Mesh,
                                           BufferColor,
                                           Vao{PeelingProgram},
                                           ProgramTag{PeelingProgram},
                                           ), (RenderProgram{PeelingProgram},))

function update(uploader::System{Uploader{K}}) where {K <: Union{DefaultProgram, PeelingProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	bcolor   = comp(BufferColor)
	mesh     = comp(Mesh)
	vao      = comp(Vao)
	prog     = singleton(uploader, RenderProgram)
	progtag  = comp(ProgramTag)
	smesh    = scomp(Mesh)

	uploaded_entities = valid_entities(vao)
	bcol_entities     = valid_entities(bcolor)
	smesh_entities    = setdiff(valid_entities(progtag, smesh), uploaded_entities) 
	mesh_entities     = setdiff(valid_entities(progtag, mesh),  uploaded_entities) 
	for (m, entities) in zip((mesh, smesh), (mesh_entities, smesh_entities))
		for e in entities
			if e ∈ bcol_entities
			    vao[e] = Vao{K}(VertexArray(prog.program, m[e].mesh, color=bcolor[e].color), e)
		    else
			    vao[e] = Vao{K}(VertexArray(prog.program, m[e].mesh, ), e)
		    end
	    end
	end
end

default_instanced_uploader_system(dio::Diorama) =
	System{Uploader{DefaultInstancedProgram}}(dio, (Mesh,
										      	    Color,
										      	    ModelMat,
										      	    Material,
										      	    Vao{DefaultInstancedProgram},
										      	    ProgramTag{DefaultInstancedProgram},
										      	    ), (RenderProgram{DefaultInstancedProgram},))

peeling_instanced_uploader_system(dio::Diorama) =
	System{Uploader{PeelingInstancedProgram}}(dio, (Mesh,
                                           			UniformColor,
                                           			ModelMat,
                                           			Material,
                                           			Vao{PeelingInstancedProgram},
                                           			ProgramTag{PeelingInstancedProgram},
                                           			),(RenderProgram{PeelingInstancedProgram},))

function update(uploader::System{Uploader{K}}) where {K <: Union{DefaultInstancedProgram, PeelingInstancedProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	smesh    = scomp(Mesh)
	ivao     = scomp(Vao{K})
	iprog    = singleton(uploader, RenderProgram{K})
	iprogtag = comp(ProgramTag{K})
	modelmat = comp(ModelMat)
	material = comp(Material)
	ucolor   = comp(UniformColor)

	instanced_entities = setdiff(valid_entities(iprogtag, smesh, modelmat, material, ucolor), valid_entities(ivao))
	if isempty(instanced_entities)
		return
	end
	for m in smesh.shared
		t_es = shared_entities(smesh, m) ∩ instanced_entities
		if !isempty(t_es)
			modelmats = Vector{Mat4f0}(undef,  length(t_es))
			ucolors   = Vector{RGBAf0}(undef,  length(t_es))
			specints  = Vector{Float32}(undef, length(t_es))
			specpows  = Vector{Float32}(undef, length(t_es))

			for (i, e) in enumerate(t_es)
				modelmats[i] = modelmat[e].modelmat
				specints[i]  = material[e].specint
				specpows[i]  = material[e].specpow
				ucolors[i]   = ucolor[e].color
			end
			tprog = iprog.program
			tmesh = smesh[t_es[1]].mesh
		    push!(ivao.shared, Vao{K}(VertexArray([generate_buffers(tprog, tmesh); generate_buffers(tprog, color=ucolors, modelmat=modelmats, specint=specints, specpow=specpows)], tmesh.faces .- GLint(1), length(t_es)), 1))
		    for e in t_es
			    ivao.data[e] = length(ivao.shared)
		    end
	    end
	end
end




#TODO we could actually make the uploader system after having defined what kind of rendersystems are there



abstract type RenderSystem  <: SystemKind   end
struct DefaultRenderer      <: RenderSystem end

default_render_system(dio::Diorama) =
	System{DefaultRenderer}(dio, (Vao{DefaultProgram},
								  Vao{DefaultInstancedProgram},
								  ProgramTag{DefaultProgram},
								  ProgramTag{DefaultInstancedProgram},
								  Spatial,
								  Material,
								  ModelMat,
								  Color,
								  Shape,
								  PointLight,
								  Camera3D), (RenderPass{DefaultPass},
								  			  RenderTarget{IOTarget},
								  			  RenderProgram{DefaultProgram},
								  			  RenderProgram{DefaultInstancedProgram}))

function set_uniform(program::GLA.Program, spatial, camera::Camera3D)
    set_uniform(program, :projview, camera.projview)
    set_uniform(program, :campos,   spatial.position)
end

function set_uniform(program::GLA.Program, pointlight::PointLight, color::UniformColor)
    set_uniform(program, Symbol("plight.color"),              RGB(color.color))
    set_uniform(program, Symbol("plight.position"),           pointlight.position)
    set_uniform(program, Symbol("plight.amb_intensity"),      pointlight.ambient)
    set_uniform(program, Symbol("plight.specular_intensity"), pointlight.specular)
    set_uniform(program, Symbol("plight.diff_intensity"),     pointlight.diffuse)
end

#maybe this should be splitted into a couple of systems
function update(renderer::System{DefaultRenderer})
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao        = comp(Vao{DefaultProgram})
	ivao       = scomp(Vao{DefaultInstancedProgram})
	spatial    = comp(Spatial)
	material   = comp(Material)
	modelmat   = comp(ModelMat)
	shape      = comp(Shape)
	ucolor     = comp(UniformColor)
	fcolor     = comp(FuncColor)
	prog       = singleton(renderer, RenderProgram{DefaultProgram})
	progtag    = comp(ProgramTag{DefaultProgram})
	iprog      = singleton(renderer, RenderProgram{DefaultInstancedProgram})
	iprogtag   = comp(ProgramTag{DefaultInstancedProgram})
    ufunc      = set_entity_uniforms_func(prog, renderer)

	light      = comp(PointLight)
	camera     = comp(Camera3D)
	renderpass = renderer.singletons[1]


	fbo = singleton(renderer, RenderTarget{IOTarget})
	bind(fbo)
	draw(fbo)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	bind(iprog)
    for i in valid_entities(light, ucolor)
	    set_uniform(iprog, light[i], ucolor[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(iprog, spatial[i], camera[i])
    end
	for vao in ivao.shared
		GLA.bind(vao.vertexarray)
		GLA.draw(vao.vertexarray)
	end

	bind(prog)
    for i in valid_entities(light, ucolor) #TODO assign prog to lights
	    set_uniform(prog, light[i], ucolor[i])
    end
    for i in valid_entities(camera, spatial)
	    set_uniform(prog, spatial[i], camera[i])
    end

	es = valid_entities(vao, spatial, material, shape, modelmat, progtag)
	if isempty(es)
		return
	end
	for e in es
		evao   = vao[e]
		ufunc(e)
		GLA.bind(evao.vertexarray)
		GLA.draw(evao.vertexarray)
	end
end

rem1(x, y) = (x - 1) % y + 1
struct DepthPeelingRenderer <: RenderSystem end

depth_peeling_render_system(dio::Diorama) =
	System{DepthPeelingRenderer}(dio, (Vao{PeelingProgram},
								       Vao{PeelingInstancedProgram},
								       ProgramTag{PeelingProgram},
								       ProgramTag{PeelingInstancedProgram},
								       ModelMat,
								       Spatial,
								       Material,
								       Shape,
								       Color,
								       PointLight,
								       Camera3D,), (RenderPass{DepthPeelingPass},
								       				RenderTarget{IOTarget},
								       				FullscreenVao,
								       				RenderProgram{PeelingProgram},
								       				RenderProgram{PeelingInstancedProgram}))

function update(renderer::System{DepthPeelingRenderer})

	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao      = comp(Vao{PeelingProgram})
	ivao     = scomp(Vao{PeelingInstancedProgram})
	spatial  = comp(Spatial)
	material = comp(Material)
	shape    = comp(Shape)
	modelmat = comp(ModelMat)
	ucolor   = comp(UniformColor)
	fcolor   = comp(FuncColor)
	peeling_program  = singleton(renderer, RenderProgram{PeelingProgram})
	ipeeling_program = singleton(renderer, RenderProgram{PeelingInstancedProgram})
	progtag  = comp(ProgramTag{PeelingProgram})
	iprogtag = comp(ProgramTag{PeelingInstancedProgram})

	ufunc = set_entity_uniforms_func(peeling_program, renderer)

	light    = comp(PointLight)
	camera   = comp(Camera3D)
	rp = renderer.singletons[1]

	peel_comp_program   = rp.programs[:peel_comp]
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

    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    glDisable(GL_BLEND)

	# # first pass: Render the previous opaque stuff first
	bind(peel_comp_program)
	set_uniform(peel_comp_program, :first_pass, true)
	set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
	set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
    bind(fullscreenvao)
    draw(fullscreenvao)
	set_uniform(peel_comp_program, :first_pass, false)
	# #TODO hack !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	separate_entities  = valid_entities(vao, spatial, material, shape, modelmat, progtag)
	instanced_entities = valid_entities(ivao)
	render_separate  = !isempty(separate_entities)
	render_instanced = !isempty(instanced_entities)
	function renderall_separate()
		#render all separate ones first
		for i in separate_entities
			evao   = vao[i]
			ufunc(i)
			GLA.bind(evao.vertexarray)
			GLA.draw(evao.vertexarray)
		end
	end
	function renderall_instanced()
		for evao in ivao.shared
			GLA.bind(evao.vertexarray)
			GLA.draw(evao.vertexarray)
		end
	end


	# first pass: Render all the transparent stuff
	# separate
	if render_separate
	    bind(peeling_program)
	    for i in valid_entities(light, ucolor)
		    set_uniform(peeling_program, light[i], ucolor[i])
	    end
	    for i in valid_entities(camera, spatial)
		    set_uniform(peeling_program, spatial[i], camera[i])
	    end

	    set_uniform(peeling_program, :first_pass, true)
	    set_uniform(peeling_program, :canvas_width, canvas_width)
	    set_uniform(peeling_program, :canvas_height, canvas_height)
		renderall_separate()
	    set_uniform(peeling_program, :first_pass, false)
    end

    #instanced
    if render_instanced
	    bind(ipeeling_program)
	    for i in valid_entities(light, ucolor)
		    set_uniform(ipeeling_program, light[i], ucolor[i])
	    end
	    for i in valid_entities(camera, spatial)
		    set_uniform(ipeeling_program, spatial[i], camera[i])
	    end
	    set_uniform(ipeeling_program, :first_pass, true)
	    set_uniform(ipeeling_program, :canvas_width, canvas_width)
	    set_uniform(ipeeling_program, :canvas_height, canvas_height)
		renderall_instanced()
	    set_uniform(ipeeling_program, :first_pass, false)
    end

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
		if render_separate
	        bind(peeling_program)
	        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
			renderall_separate()
		end
		if render_instanced
	        bind(ipeeling_program)
	        set_uniform(ipeeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
			renderall_instanced()
		end


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
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)
	meshed_entities  = valid_entities(mesh)
	smeshed_entities = valid_entities(smesh)

	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file), (spolygon, sfile)))
		for com in geomcomps
			for e in setdiff(valid_entities(com), valid_entities(meshcomp))
				meshcomp[e] = Mesh(BasicMesh(com[e].geometry))
			end
		end
	end


	funcgeometry  = comp(FuncGeometry)
	grid          = scomp(Grid)
	funccolor     = comp(FuncColor)
	cycledcolor   = comp(CycledColor)
	colorbuffers  = comp(BufferColor)
	for e in valid_entities(funcgeometry, grid)
		if has_entity(mesh, e)
			continue
		end
		values        = funcgeometry[e].geometry.(grid[e].points)
		vertices, ids = marching_cubes(values, grid[e].points, funcgeometry[e].iso_value)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]

		if cycledcolor != nothing && has_entity(cycledcolor, e)
		elseif funccolor != nothing && has_entity(funccolor, e)
			colorbuffers[e] = funccolor[e].color.(vertices)
		end
		mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end

end
		





