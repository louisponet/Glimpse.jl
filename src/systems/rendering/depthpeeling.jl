import GLAbstraction: bind, draw, color_attachment, depth_attachment

@render_program PeelingCompositingProgram 
@render_program PeelingProgram          
@render_program BlendProgram            
@render_program InstancedPeelingProgram

@render_target ColorBlendTarget
@render_target PeelTarget        

@vao PeelingVao
@instanced_vao InstancedPeelingVao

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
	(PeelingVao, PeelingProgram, BlendProgram, PeelingCompositingProgram, CompositingProgram,
	 ModelMat, Material, PointLight, UniformColor, BufferColor, Spatial, Camera3D,
	 PeelTarget, ColorBlendTarget, IOTarget)
end

function requested_components(::InstancedDepthPeelingRenderer)
	(InstancedPeelingVao, InstancedPeelingProgram, BlendProgram, PeelingCompositingProgram,
	 CompositingProgram, PointLight, UniformColor, Spatial, Camera3D,
	 PeelTarget, ColorBlendTarget, IOTarget)
end

function ECS.prepare(::Union{DepthPeelingRenderer, InstancedDepthPeelingRenderer}, dio::Diorama)
	if isempty(dio[BlendProgram])
		Entity(dio, BlendProgram(Program(blending_shaders())))
	end
	if isempty(dio[PeelingCompositingProgram])
		Entity(dio, PeelingCompositingProgram(Program(peeling_compositing_shaders())))
	end
	if isempty(dio[CompositingProgram])
		Entity(dio, CompositingProgram(Program(compositing_shaders())))
	end
	c = dio[Canvas][1]
	wh = size(c)
	while length(dio[PeelTarget]) < 2
		Entity(dio, PeelTarget(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background))
	end
	if isempty(dio[ColorBlendTarget])
		Entity(dio, ColorBlendTarget(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background))
	end
end


function update(renderer::DepthPeelingRenderer, m::ECS.AbstractManager)
	glDisableCullFace()
	vao = m[PeelingVao]
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

	peeling_program  = m[PeelingProgram][1]
	peel_comp_program   = m[PeelingCompositingProgram][1]
    blending_program    = m[BlendProgram][1]
    compositing_program = m[CompositingProgram][1]

    colorblender        = m[ColorBlendTarget][1]
    peeling_targets     = ECS.data(m[PeelTarget])[1:2]
    iofbo               = m[IOTarget][1]
    fullscreenvao       = m[FullscreenVao][1]

	set_light_camera_uniforms = (prog) -> begin
	    for e  in entities(light, ucolor, spatial)
		    set_uniform(prog, light[e], ucolor[e], spatial[e])
	    end
	    for e in entities(spatial, camera)
		    set_uniform(prog, spatial[e], camera[e])
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

	it1 = entities(vao, modelmat, material, ucolor)
	it2 = entities(vao, modelmat, material, bcolor, exclude=(ucolor,))

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
			for e in it
                evao = vao[e]
				if evao.visible
					set_model_material(modelmat[e], material[e])
					f(color[e])
					GLA.bind(evao)
					GLA.draw(evao)
				end
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

 	# first pass: Render all the transparent stuff
 	# separate
	render_start(peeling_program, renderall_separate)

 	#start peeling passes
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

function update(renderer::InstancedDepthPeelingRenderer, m::ECS.AbstractManager)
	glDisableCullFace()
	vao = m[InstancedPeelingVao]
	if isempty(vao)
		return
	end
	rem1(x, y) = (x - 1) % y + 1

	spatial  = m[Spatial]
	ucolor   = m[UniformColor]
	bcolor   = m[BufferColor]
	light    = m[PointLight]
	camera   = m[Camera3D]

	peeling_program  = m[InstancedPeelingProgram][1]
	peel_comp_program   = m[PeelingCompositingProgram][1]
    blending_program    = m[BlendProgram][1]
    compositing_program = m[CompositingProgram][1]

    colorblender        = m[ColorBlendTarget][1]
    peeling_targets     = ECS.data(m[PeelTarget])[1:2]
    iofbo               = m[IOTarget][1]
    fullscreenvao       = m[FullscreenVao][1]

	set_light_camera_uniforms = (prog) -> begin
	    for e  in entities(light, ucolor, spatial)
		    set_uniform(prog, light[e], ucolor[e], spatial[e])
	    end
	    for e in entities(spatial, camera)
		    set_uniform(prog, spatial[e], camera[e])
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
		for evao in ECS.shared_data(vao)
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
end
