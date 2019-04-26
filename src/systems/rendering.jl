struct UniformCalculator <: SystemKind end
uniform_calculator_system(dio::Diorama) = System{UniformCalculator}(dio, (Spatial, Shape, ModelMat, Dynamic), (UpdatedComponents,))
function update(sys::System{UniformCalculator})
	comp(T) = component(sys, T) 
	spatial  = comp(Spatial)
	shape    = comp(Shape)
	dyn      = comp(Dynamic)
	modelmat = comp(ModelMat)
	dynamic_entities = valid_entities(dyn)
	already_filled   = valid_entities(modelmat)
	es               = valid_entities(spatial, shape)
	for e in setdiff(es, already_filled)	 
		modelmat[e] = ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale)))
	end
	# Updating uniforms if it's updated
	uc       = singleton(sys, UpdatedComponents)
	if Spatial in uc || Shape in uc
		push!(singleton(sys, UpdatedComponents), ModelMat)
		for e in es ∩ dynamic_entities
			overwrite!(modelmat, ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale))), e)
		end
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
	vao      = comp(Vao{K})
	prog     = singleton(uploader, RenderProgram{K})
	progtag  = comp(ProgramTag{K})
	smesh    = scomp(Mesh)

	uploaded_entities = valid_entities(vao)
	bcol_entities     = valid_entities(bcolor)
	smesh_entities    = setdiff(valid_entities(progtag, smesh), uploaded_entities) 
	mesh_entities     = setdiff(valid_entities(progtag, mesh),  uploaded_entities) 
	for (m, entities) in zip((mesh, smesh), (mesh_entities, smesh_entities))
		for e in entities
			if e ∈ bcol_entities
			    vao[e] = Vao{K}(VertexArray([generate_buffers(prog.program, m[e].mesh); generate_buffers(prog.program, GEOMETRY_DIVISOR, color=bcolor[e].color)], faces(m[e].mesh).-GLint(1)), e, true)
		    else
			    vao[e] = Vao{K}(VertexArray(generate_buffers(prog.program, m[e].mesh),faces(m[e].mesh).-GLint(1)), e, true)
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
		    push!(ivao.shared, Vao{K}(VertexArray([generate_buffers(tprog, tmesh); generate_buffers(tprog, GLint(1), color=ucolors, modelmat=modelmats, specint=specints, specpow=specpows)], tmesh.faces .- GLint(1), length(t_es)), 1, true))
		    for e in t_es
			    ivao.data[e] = length(ivao.shared)
		    end
	    end
	end
end

struct UniformUploader <: SystemKind end
uniform_uploader_system(dio::Diorama) = System{UniformUploader}(dio, (Vao{DefaultInstancedProgram},
                                                                      Vao{PeelingInstancedProgram},
                                                                      ModelMat),
                                                                     (UpdatedComponents,))

function update(sys::System{UniformUploader})
	uc = singleton(sys, UpdatedComponents)
	dvao = shared_component(sys, Vao{DefaultInstancedProgram})
	pvao = shared_component(sys, Vao{PeelingInstancedProgram})

	mat = component(sys, ModelMat)
	mat_entities = valid_entities(mat)
	if ModelMat in uc.components
		upload = instanced_vao -> begin
			for v in instanced_vao.shared
				eids = shared_entities(instanced_vao, v) ∩ mat_entities 
				modelmats = Vector{Mat4f0}(undef, length(eids))
				for (i, eid)  in enumerate(eids)
					modelmats[i] = mat[eid].modelmat
				end
				if !isempty(modelmats)
					binfo = GLA.bufferinfo(v.vertexarray, :modelmat)
					if binfo != nothing
						GLA.upload_buffer_data!(binfo.buffer, modelmats)
					end
				end
			end
		end
		upload(dvao)
		upload(pvao)
	end
end



#TODO we could actually make the uploader system after having defined what kind of rendersystems are there
abstract type AbstractRenderSystem  <: SystemKind   end
struct DefaultRenderer      <: AbstractRenderSystem end

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
	prog       = singleton(renderer, RenderProgram{DefaultProgram})
	progtag    = comp(ProgramTag{DefaultProgram})
	iprog      = singleton(renderer, RenderProgram{DefaultInstancedProgram})
    ufunc      = set_entity_uniforms_func(prog, renderer)

	light      = comp(PointLight)
	camera     = comp(Camera3D)

	fbo = singleton(renderer, RenderTarget{IOTarget})
	bind(fbo)
	draw(fbo)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	function set_light_camera_uniforms(prog)
	    for i in valid_entities(light, ucolor)
		    set_uniform(prog, light[i], ucolor[i])
	    end
	    for i in valid_entities(camera, spatial)
		    set_uniform(prog, spatial[i], camera[i])
	    end
    end

	bind(iprog)
    set_light_camera_uniforms(iprog)
    
	for vao in ivao.shared
		if vao.visible
			GLA.bind(vao.vertexarray)
			GLA.draw(vao.vertexarray)
		end
	end

	bind(prog)
	set_light_camera_uniforms(prog)

	es = valid_entities(vao, spatial, material, shape, modelmat, progtag)
	for e in es
		evao   = vao[e]
		if evao.visible
			ufunc(e)
			GLA.bind(evao.vertexarray)
			GLA.draw(evao.vertexarray)
		end
	end
end

rem1(x, y) = (x - 1) % y + 1
struct DepthPeelingRenderer <: AbstractRenderSystem end

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
	fcolor   = comp(FunctionColor)
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
	separate_entities  = valid_entities(vao, spatial, material, shape, modelmat, progtag)
	instanced_entities = valid_entities(ivao)
	render_separate  = !isempty(separate_entities)
	render_instanced = !isempty(instanced_entities)
	function renderall_separate()
		#render all separate ones first
		for i in separate_entities
			evao   = vao[i]
			if evao.visible
				ufunc(i)
				GLA.bind(evao.vertexarray)
				GLA.draw(evao.vertexarray)
			end
		end
	end

	function renderall_instanced()
		for evao in ivao.shared
			if evao.visible
				GLA.bind(evao.vertexarray)
				GLA.draw(evao.vertexarray)
			end
		end
	end

	function render_start(prog, renderfunc)
	    bind(prog)
	    for i in valid_entities(light, ucolor)
		    set_uniform(prog, light[i], ucolor[i])
	    end
	    for i in valid_entities(camera, spatial)
		    set_uniform(prog, spatial[i], camera[i])
	    end

	    set_uniform(prog, :first_pass, true)
	    set_uniform(prog, :canvas_width, canvas_width)
	    set_uniform(prog, :canvas_height, canvas_height)
		renderfunc()
	    set_uniform(prog, :first_pass, false)
    end

	# first pass: Render all the transparent stuff
	# separate
	if render_separate
		render_start(peeling_program, renderall_separate)
    end

    #instanced
    if render_instanced
	    render_start(ipeeling_program, renderall_instanced)
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

struct FinalRenderer <: AbstractRenderSystem end
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
