import GLAbstraction: bind, draw, color_attachment, depth_attachment

struct PeelingCompositeProgram <: ProgramKind end
struct PeelingProgram          <: ProgramKind end
struct InstancedPeelingProgram <: ProgramKind end

#can't the colorblender be the IOTarget?
struct ColorBlendTarget  <: RenderTargetKind end
struct PeelTarget        <: RenderTargetKind end

# Using the shared uploader system inside uploading.jl
# PeelingUploader(dio::Diorama) = Uploader(PeelingProgram, dio)

# PeelingInstancedUploader(dio::Diorama) = InstancedUploader(PeelingInstancedProgram, dio)

# struct DepthPeelingRenderer <: AbstractRenderSystem
# 	data          ::SystemData
# 	peel1_target  ::RenderTarget{PeelTarget}
# 	peel2_target  ::RenderTarget{PeelTarget}
# 	blender_target::RenderTarget{ColorBlendTarget}
# 	peel_comp_program::GLA.Program
# 	blend_program    ::GLA.Program
# 	comp_program     ::GLA.Program
# 	num_passes ::Int

# 	function DepthPeelingRenderer(dio::Diorama, num_passes=5)
# 		components = (Vao{PeelingProgram},
# 		              Vao{PeelingInstancedProgram},
# 		              ProgramTag{PeelingProgram},
# 		              ProgramTag{PeelingInstancedProgram},
# 		              ModelMat,
# 		              Spatial,
# 		              Material,
# 		              Shape,
# 		              Color,
# 		              PointLight,
# 		              Camera3D)
# 	    singletons = (RenderTarget{IOTarget},
# 	  			      FullscreenVao,
# 	  			      RenderProgram{PeelingProgram},
# 	  			      RenderProgram{PeelingInstancedProgram})

# 		data       = SystemData(dio, components, singletons)
# 		wh         = size(dio)
# 		background = background_color(dio)

# 	    peel_comp_prog      = Program(peeling_compositing_shaders())
# 	    comp_prog           = Program(compositing_shaders())
# 	    blend_prog          = Program(blending_shaders())

# 	    color_blender, peel1, peel2 = [FrameBuffer(values(wh), (RGBA{Float32}, GLA.Depth{Float32}), true) for i= 1:3]
#         return new(data,
#                    RenderTarget{PeelTarget}(peel1, background),
#                    RenderTarget{PeelTarget}(peel2, background),
#                    RenderTarget{ColorBlendTarget}(color_blender, background),
#                    peel_comp_prog,    
#                    blend_prog,
#                    comp_prog,
#                    num_passes)
#     end
# end

# function update_indices!(sys::DepthPeelingRenderer)
# 	comp(T)  = component(sys, T)
# 	spat     = comp(Spatial)
# 	sys.data.indices = [valid_entities(comp(PointLight), comp(UniformColor), spat),
#                         valid_entities(comp(Camera3D), spat),
# 		                valid_entities(comp(Vao{PeelingProgram}),
# 		                               spat,
# 		                               comp(Material),
# 		                               comp(Shape),
# 		                               comp(ModelMat),
# 		                               comp(ProgramTag{PeelingProgram})),                        
#                         valid_entities(shared_component(sys, Vao{PeelingInstancedProgram}))]
# end

# function update(renderer::DepthPeelingRenderer)
# 	if isempty(indices(renderer))
# 		return
# 	end
# 	allempty = true
# 	for i in indices(renderer)
# 		if !isempty(i)
# 			allempty = false
# 		end
# 	end
# 	if allempty
# 		return
# 	end
# 	rem1(x, y) = (x - 1) % y + 1
# 	comp(T)  = component(renderer, T)
# 	scomp(T) = shared_component(renderer, T)
# 	vao      = comp(Vao{PeelingProgram})
# 	ivao     = scomp(Vao{PeelingInstancedProgram})
# 	spatial  = comp(Spatial)
# 	material = comp(Material)
# 	shape    = comp(Shape)
# 	modelmat = comp(ModelMat)
# 	ucolor   = comp(UniformColor)
# 	peeling_program  = singleton(renderer, RenderProgram{PeelingProgram})
# 	ipeeling_program = singleton(renderer, RenderProgram{PeelingInstancedProgram})

# 	ufunc = set_entity_uniforms_func(peeling_program, renderer)

# 	light    = comp(PointLight)
# 	camera   = comp(Camera3D)

# 	peel_comp_program   = renderer.peel_comp_program
#     blending_program    = renderer.blend_program
#     compositing_program = renderer.comp_program

#     colorblender        = renderer.blender_target
#     peeling_targets     = [renderer.peel1_target, renderer.peel2_target]
#     iofbo               = singleton(renderer, RenderTarget{IOTarget})
#     fullscreenvao       = singleton(renderer, FullscreenVao)

#     bind(colorblender)
#     draw(colorblender)
#     clear!(colorblender)
#     #TODO change this nonsense
#     canvas_width, canvas_height = Float32.(size(iofbo))

#     resize!(colorblender, (Int(canvas_width), Int(canvas_height)))
#     resize!(peeling_targets[1], (Int(canvas_width), Int(canvas_height)))
#     resize!(peeling_targets[2], (Int(canvas_width), Int(canvas_height)))

#     glEnable(GL_DEPTH_TEST)
#     glDepthFunc(GL_LEQUAL)
#     glDisable(GL_BLEND)

# 	# # first pass: Render the previous opaque stuff first
# 	bind(peel_comp_program)
# 	set_uniform(peel_comp_program, :first_pass, true)
# 	set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
# 	set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
#     bind(fullscreenvao)
#     draw(fullscreenvao)
# 	set_uniform(peel_comp_program, :first_pass, false)
# 	separate_entities  = indices(renderer)[3]
# 	instanced_entities = indices(renderer)[4]
# 	render_separate  = !isempty(separate_entities)
# 	render_instanced = !isempty(instanced_entities)
# 	function renderall_separate()
# 		#render all separate ones first
# 		for i in separate_entities
# 			evao   = vao[i]
# 			if evao.visible
# 				ufunc(i)
# 				GLA.bind(evao)
# 				GLA.draw(evao)
# 			end
# 		end
# 	end

# 	function renderall_instanced()
# 		for evao in ivao.shared
# 			if evao.visible
# 				GLA.bind(evao)
# 				GLA.draw(evao)
# 			end
# 		end
# 	end

# 	function render_start(prog, renderfunc)
# 	    bind(prog)
# 	    for i in indices(renderer)[1]
# 		    set_uniform(prog, light[i], ucolor[i], spatial[i])
# 	    end
# 	    for i in indices(renderer)[2]
# 		    set_uniform(prog, spatial[i], camera[i])
# 	    end

# 	    set_uniform(prog, :first_pass, true)
# 	    set_uniform(prog, :canvas_width, canvas_width)
# 	    set_uniform(prog, :canvas_height, canvas_height)
# 		renderfunc()
# 	    set_uniform(prog, :first_pass, false)
#     end

# 	# first pass: Render all the transparent stuff
# 	# separate
# 	if render_separate
# 		render_start(peeling_program, renderall_separate)
#     end

#     #instanced
#     if render_instanced
# 	    render_start(ipeeling_program, renderall_instanced)
#     end

# 	#start peeling passes
#     for layer=1:renderer.num_passes
#         currid  = rem1(layer, 2)
#         currfbo = peeling_targets[currid]
#         previd  =  3 - currid
#         prevfbo = layer == 1 ? colorblender : peeling_targets[previd]
#         bind(currfbo)
#         draw(currfbo)
#         glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
#         glEnable(GL_DEPTH_TEST)
#         glDisable(GL_BLEND)

# 		# peel: Render all opaque stuff
# 		bind(peel_comp_program)
# 		set_uniform(peel_comp_program, :color_texture, (0, color_attachment(iofbo, 1)))
# 		set_uniform(peel_comp_program, :depth_texture, (1, depth_attachment(iofbo)))
# 		set_uniform(peel_comp_program, :prev_depth,    (2, depth_attachment(prevfbo)))
# 	    bind(fullscreenvao)
# 	    draw(fullscreenvao)

# 		# peel: Render all the transparent stuff
# 		if render_separate
# 	        bind(peeling_program)
# 	        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
# 			renderall_separate()
# 		end
# 		if render_instanced
# 	        bind(ipeeling_program)
# 	        set_uniform(ipeeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
# 			renderall_instanced()
# 		end


#         # bind(peeling_instanced_program)
#         # set_uniform(peeling_instanced_program, :depth_texture, (0, depth_attachment(prevfbo)))
#         # render(instanced_renderables(rp), peeling_instanced_program)
        
#         # blend: push the new peel to the colorblender using correct alphas
#         bind(colorblender)
#         draw(colorblender)

#         glDisable(GL_DEPTH_TEST)
#         glEnable(GL_BLEND)
#         glBlendEquation(GL_FUNC_ADD)
#         glBlendFuncSeparate(GL_DST_ALPHA, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA)

#         bind(blending_program)
#         set_uniform(blending_program, :color_texture, (0, color_attachment(currfbo, 1)))

#         bind(fullscreenvao)
#         draw(fullscreenvao)
#     end
#     bind(iofbo)
#     draw(iofbo)
# 	glDisable(GL_BLEND)

#     bind(compositing_program)
#     set_uniform(compositing_program, :color_texture, (0, color_attachment(colorblender, 1)))
#     bind(fullscreenvao)
#     draw(fullscreenvao)
#     # glFlush()
# end
