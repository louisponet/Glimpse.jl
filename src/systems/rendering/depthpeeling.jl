import GLAbstraction: bind, draw, color_attachment, depth_attachment

struct PeelingCompositingProgram <: ProgramKind end
struct PeelingProgram          <: ProgramKind end
struct BlendProgram            <: ProgramKind end
struct InstancedPeelingProgram <: ProgramKind end

#can't the colorblender be the IOTarget?
struct ColorBlendTarget  <: RenderTargetKind end
struct PeelTarget        <: RenderTargetKind end

ECS.preferred_component_type(::Type{Vao{InstancedPeelingProgram}}) = SharedComponent
ECS.preferred_component_type(::Type{Vao{PeelingProgram}}) = Component

# Using the shared uploader system inside uploading.jl
PeelingUploader() = Uploader{PeelingProgram}()
InstancedPeelingUploader() = Uploader{InstancedPeelingProgram}()

@with_kw struct DepthPeelingRenderer <: AbstractRenderSystem
	num_passes::Int = 5
end

@with_kw struct InstancedDepthPeelingRenderer <: AbstractRenderSystem
	num_passes::Int = 5
end

function requested_components(::DepthPeelingRenderer)
	pp = PeelingProgram
	(Vao{pp}, RenderProgram{pp}, RenderProgram{BlendProgram}, RenderProgram{PeelingCompositingProgram},
	 RenderProgram{CompositingProgram},
	 ModelMat, Material, PointLight, UniformColor, BufferColor, Spatial, Camera3D,
	 RenderTarget{PeelTarget}, RenderTarget{ColorBlendTarget}, RenderTarget{IOTarget})
end

function requested_components(::InstancedDepthPeelingRenderer)
	pp = InstancedPeelingProgram
	(Vao{pp}, RenderProgram{pp}, RenderProgram{BlendProgram}, RenderProgram{PeelingCompositingProgram},
	 RenderProgram{CompositingProgram}, PointLight, UniformColor, Spatial, Camera3D,
	 RenderTarget{PeelTarget}, RenderTarget{ColorBlendTarget}, RenderTarget{IOTarget})
end

function ECS.prepare(::Union{DepthPeelingRenderer, InstancedDepthPeelingRenderer}, dio::Diorama)
	if isempty(dio[RenderProgram{BlendProgram}])
		Entity(dio, RenderProgram{BlendProgram}(Program(blending_shaders())))
	end
	if isempty(dio[RenderProgram{PeelingCompositingProgram}])
		Entity(dio, RenderProgram{PeelingCompositingProgram}(Program(peeling_compositing_shaders())))
	end
	if isempty(dio[RenderProgram{CompositingProgram}])
		Entity(dio, RenderProgram{CompositingProgram}(Program(compositing_shaders())))
	end
	c = dio[Canvas][1]
	wh = size(c)
	while length(dio[RenderTarget{PeelTarget}]) < 2
		Entity(dio, RenderTarget{PeelTarget}(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background))
	end
	if isempty(dio[RenderTarget{ColorBlendTarget}])
		Entity(dio, RenderTarget{ColorBlendTarget}(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background))
	end
end


function (renderer::DepthPeelingRenderer)(m)
	glDisableCullFace()
	vao = m[Vao{PeelingProgram}]
	if isempty(vao)
		return
	end
	rem1(x, y) = (x - 1) % y + 1

	spatial  = m[Spatial]
	material = m[Material]
	modelmat = m[ModelMat]
	ucolor   = m[UniformColor]
	bcolor   = m[BufferColor]
	light    = m[PointLight]
	camera   = m[Camera3D]

	peeling_program  = m[RenderProgram{PeelingProgram}][1]
	peel_comp_program   = m[RenderProgram{PeelingCompositingProgram}][1]
    blending_program    = m[RenderProgram{BlendProgram}][1]
    compositing_program = m[RenderProgram{CompositingProgram}][1]

    colorblender        = m[RenderTarget{ColorBlendTarget}][1]
    peeling_targets     = ECS.data(m[RenderTarget{PeelTarget}])[1:2]
    iofbo               = m[RenderTarget{IOTarget}][1]
    fullscreenvao       = m[FullscreenVao][1]

	set_light_camera_uniforms = (prog) -> begin
	    for (l, c, s) in zip(light, ucolor, spatial)
		    set_uniform(prog, l, c, s)
	    end
	    for (s, c) in zip(spatial, camera)
		    set_uniform(prog, s, c)
	    end
    end

	set_model_material = (e_modelmat, e_material) -> begin
		set_uniform(peeling_program, :specint, e_material.specint)
		set_uniform(peeling_program, :specpow, e_material.specpow)
		set_uniform(peeling_program, :modelmat, e_modelmat.modelmat)
	end

# 	ufunc = set_entity_uniforms_func(peeling_program, renderer)

# 	ivao     = scomp(Vao{PeelingInstancedProgram})
# 	ipeeling_program = singleton(renderer, RenderProgram{PeelingInstancedProgram})

    bind(colorblender)
    draw(colorblender)
    clear!(colorblender)
#     #TODO change this nonsense
    canvas_width, canvas_height = Float32.(size(iofbo))

    resize!(colorblender, (Int(canvas_width), Int(canvas_height)))
    resize!(peeling_targets[1], (Int(canvas_width), Int(canvas_height)))
    resize!(peeling_targets[2], (Int(canvas_width), Int(canvas_height)))

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

# 	separate_entities  = indices(renderer)[3]
# 	instanced_entities = indices(renderer)[4]
# 	render_separate  = !isempty(separate_entities)
# 	render_instanced = !isempty(instanced_entities)
	it1 = zip(vao, modelmat, material, ucolor)
	it2 = zip(vao, modelmat, material, bcolor, exclude=(ucolor,))
	ufunc = (e_color) -> begin
		set_uniform(peeling_program, :uniform_color, e_color.color)
		set_uniform(peeling_program, :is_uniform, true)
	end
	bfunc = (e_color) -> begin
		set_uniform(peeling_program, :is_uniform, false)
	end

	renderall_separate = () -> begin
		set_light_camera_uniforms(peeling_program)
		for (it, f) in zip((it1,it2), (ufunc, bfunc)) 
			for (evao, e_modelmat, e_material, e_color) in it
				if evao.visible
					set_model_material(e_modelmat, e_material)
					f(e_color)
					GLA.bind(evao)
					GLA.draw(evao)
				end
			end
		end
	end

# 	function renderall_instanced()
# 		for evao in ivao.shared
# 			if evao.visible
# 				GLA.bind(evao)
# 				GLA.draw(evao)
# 			end
# 		end
# 	end

	function render_start(prog, renderfunc)
	    bind(prog)
	    set_light_camera_uniforms(prog)
	    set_uniform(prog, :first_pass, true)
	    set_uniform(prog, :canvas_width, canvas_width)
	    set_uniform(prog, :canvas_height, canvas_height)
		renderfunc()
	    set_uniform(prog, :first_pass, false)
    end

# 	# first pass: Render all the transparent stuff
# 	# separate
# 	if render_separate
	render_start(peeling_program, renderall_separate)
#     end

#     #instanced
#     if render_instanced
# 	    render_start(ipeeling_program, renderall_instanced)
#     end

# 	#start peeling passes
    for layer=1:renderer.num_passes
        currid  = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd  =  3 - currid
        prevfbo = layer == 1 ? colorblender : peeling_targets[previd]
        bind(currfbo)
        draw(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glEnable(GL_DEPTH_TEST)
        glDisable(GL_BLEND)

# 		# peel: Render all opaque stuff
		bind(peel_comp_program)
		set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
		set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
		set_uniform(peel_comp_program, :prev_depth,    (2, depth_attachment(prevfbo)))
	    bind(fullscreenvao)
	    draw(fullscreenvao)

# 		# peel: Render all the transparent stuff
# 		if render_separate
        bind(peeling_program)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
		renderall_separate()
# 		end
# 		if render_instanced
# 	        bind(ipeeling_program)
# 	        set_uniform(ipeeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
# 			renderall_instanced()
# 		end


        
#         # blend: push the new peel to the colorblender using correct alphas
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
    # glFlush()
end

function (renderer::InstancedDepthPeelingRenderer)(m)
	glDisableCullFace()
	vao = m[Vao{InstancedPeelingProgram}]
	if isempty(vao)
		return
	end
	rem1(x, y) = (x - 1) % y + 1

	spatial  = m[Spatial]
	ucolor   = m[UniformColor]
	bcolor   = m[BufferColor]
	light    = m[PointLight]
	camera   = m[Camera3D]

	peeling_program  = m[RenderProgram{InstancedPeelingProgram}][1]
	peel_comp_program   = m[RenderProgram{PeelingCompositingProgram}][1]
    blending_program    = m[RenderProgram{BlendProgram}][1]
    compositing_program = m[RenderProgram{CompositingProgram}][1]

    colorblender        = m[RenderTarget{ColorBlendTarget}][1]
    peeling_targets     = ECS.data(m[RenderTarget{PeelTarget}])[1:2]
    iofbo               = m[RenderTarget{IOTarget}][1]
    fullscreenvao       = m[FullscreenVao][1]

	set_light_camera_uniforms = (prog) -> begin
	    for (l, c, s) in zip(light, ucolor, spatial)
		    set_uniform(prog, l, c, s)
	    end
	    for (s, c) in zip(spatial, camera)
		    set_uniform(prog, s, c)
	    end
    end

    bind(colorblender)
    draw(colorblender)
    clear!(colorblender)
#     #TODO change this nonsense
    canvas_width, canvas_height = Float32.(size(iofbo))

    resize!(colorblender, (Int(canvas_width), Int(canvas_height)))
    resize!(peeling_targets[1], (Int(canvas_width), Int(canvas_height)))
    resize!(peeling_targets[2], (Int(canvas_width), Int(canvas_height)))

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

	renderall_instanced = () -> begin
		set_light_camera_uniforms(peeling_program)
		for evao in vao
			if evao.visible
				GLA.bind(evao)
				GLA.draw(evao)
			end
		end
	end

	function render_start(prog, renderfunc)
	    bind(prog)
	    set_light_camera_uniforms(prog)
	    set_uniform(prog, :first_pass, true)
	    set_uniform(prog, :canvas_width, canvas_width)
	    set_uniform(prog, :canvas_height, canvas_height)
		renderfunc()
	    set_uniform(prog, :first_pass, false)
    end

	render_start(peeling_program, renderall_instanced)

# 	#start peeling passes
    for layer=1:renderer.num_passes
        currid  = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd  =  3 - currid
        prevfbo = layer == 1 ? colorblender : peeling_targets[previd]
        bind(currfbo)
        draw(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glEnable(GL_DEPTH_TEST)
        glDisable(GL_BLEND)

# 		# peel: Render all opaque stuff
		bind(peel_comp_program)
		set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
		set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
		set_uniform(peel_comp_program, :prev_depth,    (2, depth_attachment(prevfbo)))
	    bind(fullscreenvao)
	    draw(fullscreenvao)

# 		# peel: Render all the transparent stuff
# 		if render_separate
        bind(peeling_program)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
		renderall_instanced()
        
#         # blend: push the new peel to the colorblender using correct alphas
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
    # glFlush()
end
