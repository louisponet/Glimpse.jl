struct UniformCalculator <: System
	data::SystemData
end
UniformCalculator(dio::Diorama) = UniformCalculator(SystemData(dio, (Spatial, Shape, ModelMat, Dynamic, Camera3D), (UpdatedComponents,)))
system_data(u::UniformCalculator) = u.data

function update_indices!(sys::UniformCalculator)
	val_es(x...)  = valid_entities(sys, x...)
	dynamic_entities = val_es(Dynamic)
	already_filled   = val_es(ModelMat)
	es               = val_es(Spatial, Shape)
	es1              = setdiff(setdiff(val_es(Spatial), val_es(Shape)), val_es(Camera3D))
	sys.data.indices = [setdiff(es, already_filled),
                        es ∩ dynamic_entities,
                        setdiff(es1, already_filled),
                        es1 ∩ dynamic_entities]
end

function update(sys::UniformCalculator)
	comp(T) = component(sys, T) 
	spatial  = comp(Spatial)
	shape    = comp(Shape)
	dyn      = comp(Dynamic)
	modelmat = comp(ModelMat)
	for e in indices(sys)[1]
		modelmat[e] = ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale)))
	end
	for e in indices(sys)[3]
		modelmat[e] = ModelMat(translmat(spatial[e].position))
	end
	# Updating uniforms if it's updated
	uc       = singleton(sys, UpdatedComponents)
	if Spatial in uc || Shape in uc
		push!(singleton(sys, UpdatedComponents), ModelMat)
		Threads.@threads for e in indices(sys)[2]
			overwrite!(modelmat, ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale))), e)
		end
		Threads.@threads for e in indices(sys)[4]
			overwrite!(modelmat, ModelMat(translmat(spatial[e].position)), e)
		end
	end
end

struct DefaultProgram          <: ProgramKind end
struct DefaultInstancedProgram <: ProgramKind end
struct PeelingCompositeProgram <: ProgramKind end
struct PeelingProgram          <: ProgramKind end
struct PeelingInstancedProgram <: ProgramKind end
struct LineProgram             <: ProgramKind end
struct TextProgram             <: ProgramKind end

function set_entity_uniforms_func(render_program::RenderProgram{<:Union{DefaultProgram, PeelingProgram, LineProgram}}, system::System)
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
function set_entity_uniforms_func(render_program::RenderProgram{LineProgram}, system::System)
    prog = render_program.program
    comp(T)  = component(system, T)
    modelmat = comp(ModelMat)
    line     = comp(Line)
	return e -> begin
		set_uniform(prog, :modelmat,   modelmat[e].modelmat)
		set_uniform(prog, :thickness,  line[e].thickness)
		set_uniform(prog, :MiterLimit, line[e].miter)
	end
end

struct Uploader{P <: ProgramKind} <: System
	data ::SystemData
end
Uploader(::Type{P}, dio::Diorama) where {P<:ProgramKind} = 
	Uploader{P}(SystemData(dio, (Mesh, BufferColor, Vao{P}, ProgramTag{P}), (RenderProgram{P},)))

system_data(u::Uploader) = u.data

DefaultUploader(dio::Diorama) = Uploader(DefaultProgram, dio)
PeelingUploader(dio::Diorama) = Uploader(PeelingProgram, dio)
LinesUploader(dio::Diorama)   = Uploader(LineProgram,    dio)

function update_indices!(uploader::Uploader{K}) where {K <: Union{DefaultProgram, PeelingProgram, LineProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	progtag  = comp(ProgramTag{K})

	uploaded_entities = valid_entities(comp(Vao{K}))
	uploader.data.indices  = [setdiff(valid_entities(progtag, comp(Mesh)), uploaded_entities),
	                          setdiff(valid_entities(progtag, scomp(Mesh)),  uploaded_entities),
	                          valid_entities(comp(BufferColor))]
end

function update(uploader::Uploader{K}) where {K <: Union{DefaultProgram, PeelingProgram, LineProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	bcolor   = comp(BufferColor)
	mesh     = comp(Mesh)
	vao      = comp(Vao{K})
	prog     = singleton(uploader, RenderProgram{K})
	progtag  = comp(ProgramTag{K})
	smesh    = scomp(Mesh)
	for (i, m) in enumerate((mesh, smesh))
		for e in indices(uploader)[i]
			if e ∈ indices(uploader)[end]
				buffers = [generate_buffers(prog.program, m[e].mesh); generate_buffers(prog.program, GEOMETRY_DIVISOR, color=bcolor[e].color)]
		    else
			    buffers = generate_buffers(prog.program, m[e].mesh)
		    end
		    if K == LineProgram
			    vao[e] = Vao{K}(VertexArray(buffers, 11), true)
		    else
			    vao[e] = Vao{K}(VertexArray(buffers, faces(m[e].mesh) .- GLint(1)), true)
		    end
	    end
	end
end

InstancedUploader(::Type{P}, dio::Diorama) where {P<:ProgramKind} =
	Uploader{P}(SystemData(dio, (Mesh,
				      	         UniformColor,
				      	         ModelMat,
				      	         Material,
				      	         Vao{P},
				      	         ProgramTag{P},
			      	            ), (RenderProgram{P},)))

DefaultInstancedUploader(dio::Diorama) = InstancedUploader(DefaultInstancedProgram, dio)
PeelingInstancedUploader(dio::Diorama) = InstancedUploader(PeelingInstancedProgram, dio)

function update_indices!(uploader::Uploader{K}) where {K <: Union{DefaultInstancedProgram, PeelingInstancedProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	smesh    = scomp(Mesh)
	ivao     = scomp(Vao{K})
	iprog    = singleton(uploader, RenderProgram{K})
	iprogtag = comp(ProgramTag{K})
	modelmat = comp(ModelMat)
	material = comp(Material)
	ucolor   = comp(UniformColor)
	uploader.data.indices = [setdiff(valid_entities(iprogtag, smesh, modelmat, material, ucolor), valid_entities(ivao))]
	for m in smesh.shared
		push!(uploader.data.indices, shared_entities(smesh, m) ∩ indices(uploader)[1])
	end
end

function update(uploader::Uploader{K}) where {K <: Union{DefaultInstancedProgram, PeelingInstancedProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	smesh    = scomp(Mesh)
	ivao     = scomp(Vao{K})
	iprog    = singleton(uploader, RenderProgram{K})
	iprogtag = comp(ProgramTag{K})
	modelmat = comp(ModelMat)
	material = comp(Material)
	ucolor   = comp(UniformColor)

	instanced_entities = indices(uploader)[1]
	if isempty(instanced_entities)
		return
	end
	for (i, m) in enumerate(smesh.shared)
		t_es = indices(uploader)[i+1]
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
		    push!(ivao.shared, Vao{K}(VertexArray([generate_buffers(tprog, tmesh); generate_buffers(tprog, GLint(1), color=ucolors, modelmat=modelmats, specint=specints, specpow=specpows)], tmesh.faces .- GLint(1), length(t_es)), true))
		    for e in t_es
			    ivao.data[e] = length(ivao.shared)
		    end
	    end
	end
end

struct UniformUploader <: System
	data ::SystemData
end
UniformUploader(dio::Diorama) = UniformUploader(SystemData(dio, (Vao{DefaultInstancedProgram},
                                                                 Vao{PeelingInstancedProgram},
                                                                 ModelMat),
                                                                (UpdatedComponents,)))
system_data(u::UniformUploader) = u.data

function update_indices!(sys::UniformUploader)
	mat_entities = valid_entities(component(sys, ModelMat))
	dvao         = shared_component(sys, Vao{DefaultInstancedProgram})
	pvao         = shared_component(sys, Vao{PeelingInstancedProgram})
	tids = Vector{Int}[]
	for v in dvao.shared 
		push!(tids, shared_entities(dvao, v) ∩ mat_entities)
	end
	for v in pvao.shared 
		push!(tids, shared_entities(pvao, v) ∩ mat_entities)
	end
	sys.data.indices = tids                       
end

function find_contiguous_bounds(indices)
	ranges = UnitRange[]
	i = 1
	cur_start = indices[1]
	while i <= length(indices) - 1
		id = indices[i]
		id_1 = indices[i + 1]
		if id_1 - id != 1
			push!(ranges, cur_start:id)
			cur_start = id_1
		end
		i += 1
	end
	push!(ranges, cur_start:indices[end])
	return ranges
end

function update(sys::UniformUploader)
	uc = singleton(sys, UpdatedComponents)
	dvao = shared_component(sys, Vao{DefaultInstancedProgram})
	pvao = shared_component(sys, Vao{PeelingInstancedProgram})

	mat = component(sys, ModelMat)
	matsize = sizeof(eltype(mat))
	indices_id = 1
	if ModelMat in uc.components
		upload = instanced_vao -> begin
			for v in instanced_vao.shared
				eids = indices(sys)[indices_id]
				contiguous_ranges = find_contiguous_bounds(eids)
				offset = 0
				if !isempty(eids)
					binfo = GLA.bufferinfo(v.vertexarray, :modelmat)
					if binfo != nothing
						GLA.bind(binfo.buffer)
						for r in contiguous_ranges
							s = length(r) * matsize
							glBufferSubData(binfo.buffer.buffertype, offset, s, pointer(mat, r[1]))
							offset += s
						end
						GLA.unbind(binfo.buffer)
					end
				end
			end
		end
		upload(dvao)
		upload(pvao)
	end
end



#TODO we could actually make the uploader system after having defined what kind of rendersystems are there
abstract type AbstractRenderSystem  <: System   end
struct DefaultRenderer <: AbstractRenderSystem
	data ::SystemData
end
DefaultRenderer(dio::Diorama) =
	DefaultRenderer(SystemData(dio, (Vao{DefaultProgram},
								     Vao{DefaultInstancedProgram},
								     Vao{LineProgram},
								     ProgramTag{DefaultProgram},
								     ProgramTag{DefaultInstancedProgram},
								     ProgramTag{LineProgram},
								     Spatial,
								     Material,
								     ModelMat,
								     Color,
								     Shape,
								     PointLight,
								     Line,
								     Camera3D), (RenderPass{DefaultPass},
								     			  RenderTarget{IOTarget},
								     			  RenderProgram{DefaultProgram},
								     			  RenderProgram{DefaultInstancedProgram},
								     			  RenderProgram{LineProgram})))
system_data(r::DefaultRenderer) = r.data

function set_uniform(program::GLA.Program, spatial, camera::Camera3D)
    set_uniform(program, :projview, camera.projview)
    set_uniform(program, :campos,   spatial.position)
end

function set_uniform(program::GLA.Program, pointlight::PointLight, color::UniformColor, spatial::Spatial)
    set_uniform(program, Symbol("plight.color"),              RGB(color.color))
    set_uniform(program, Symbol("plight.position"),           spatial.position)
    set_uniform(program, Symbol("plight.amb_intensity"),      pointlight.ambient)
    set_uniform(program, Symbol("plight.specular_intensity"), pointlight.specular)
    set_uniform(program, Symbol("plight.diff_intensity"),     pointlight.diffuse)
end

function update_indices!(sys::DefaultRenderer)
	comp(T)  = component(sys, T)
	spat     = comp(Spatial)
	sys.data.indices = [valid_entities(comp(PointLight), comp(UniformColor), spat),
                        valid_entities(comp(Camera3D), spat),
		                valid_entities(comp(Vao{DefaultProgram}),
		                               spat,
		                               comp(Material),
		                               comp(Shape),
		                               comp(ModelMat),
		                               comp(ProgramTag{DefaultProgram})),
                        valid_entities(comp(Vao{LineProgram}),
                                       comp(Line),
		                               comp(ModelMat),
		                               comp(ProgramTag{LineProgram}))]                       
end


#maybe this should be splitted into a couple of systems
function update(renderer::DefaultRenderer)
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao      = comp(Vao{DefaultProgram})
	ivao     = scomp(Vao{DefaultInstancedProgram})
	spatial  = comp(Spatial)
	material = comp(Material)
	modelmat = comp(ModelMat)
	shape    = comp(Shape)
	ucolor   = comp(UniformColor)
	prog     = singleton(renderer, RenderProgram{DefaultProgram})


	iprog         = singleton(renderer, RenderProgram{DefaultInstancedProgram})
    ufunc_default = set_entity_uniforms_func(prog, renderer)

	light         = comp(PointLight)

	line_prog     = singleton(renderer, RenderProgram{LineProgram})
	line_vao      = comp(Vao{LineProgram})
    ufunc_lines   = set_entity_uniforms_func(line_prog, renderer)

	iprog         = singleton(renderer, RenderProgram{DefaultInstancedProgram})
    ufunc_default = set_entity_uniforms_func(prog, renderer)

	light         = comp(PointLight)
	camera        = comp(Camera3D)

	fbo           = singleton(renderer, RenderTarget{IOTarget})
	bind(fbo)
	draw(fbo)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	function set_light_camera_uniforms(prog)
	    for i in indices(renderer)[1]
		    set_uniform(prog, light[i], ucolor[i], spatial[i])
	    end
	    for i in indices(renderer)[2]
		    set_uniform(prog, spatial[i], camera[i])
	    end
    end
	#Render instanced-renderables
	bind(iprog)
    set_light_camera_uniforms(iprog)
    
	for vao in ivao.shared
		if vao.visible
			GLA.bind(vao)
			GLA.draw(vao)
		end
	end

	#Render non-instanced renderables
	bind(prog)
	set_light_camera_uniforms(prog)

	for e in indices(renderer)[3]
		evao   = vao[e]
		if evao.visible
			ufunc_default(e)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end

	#Render lines
	bind(line_prog)
	set_uniform(line_prog, :Viewport, Vec2f0(size(singleton(renderer, RenderTarget{IOTarget}))))
	set_light_camera_uniforms(line_prog)
	for e in indices(renderer)[4]
		evao   = line_vao[e]
		if evao.visible
			ufunc_lines(e)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end


struct DepthPeelingRenderer <: AbstractRenderSystem
	data ::SystemData
end
DepthPeelingRenderer(dio::Diorama) =
	DepthPeelingRenderer(SystemData(dio, (Vao{PeelingProgram},
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
								          				RenderProgram{PeelingInstancedProgram})))
system_data(d::DepthPeelingRenderer) = d.data

function update_indices!(sys::DepthPeelingRenderer)
	comp(T)  = component(sys, T)
	spat     = comp(Spatial)
	sys.data.indices = [valid_entities(comp(PointLight), comp(UniformColor), spat),
                        valid_entities(comp(Camera3D), spat),
		                valid_entities(comp(Vao{PeelingProgram}),
		                               spat,
		                               comp(Material),
		                               comp(Shape),
		                               comp(ModelMat),
		                               comp(ProgramTag{PeelingProgram})),                        
                        valid_entities(shared_component(sys, Vao{PeelingInstancedProgram}))]
end

function update(renderer::DepthPeelingRenderer)
	rem1(x, y) = (x - 1) % y + 1
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)
	vao      = comp(Vao{PeelingProgram})
	ivao     = scomp(Vao{PeelingInstancedProgram})
	spatial  = comp(Spatial)
	material = comp(Material)
	shape    = comp(Shape)
	modelmat = comp(ModelMat)
	ucolor   = comp(UniformColor)
	peeling_program  = singleton(renderer, RenderProgram{PeelingProgram})
	ipeeling_program = singleton(renderer, RenderProgram{PeelingInstancedProgram})

	ufunc = set_entity_uniforms_func(peeling_program, renderer)

	light    = comp(PointLight)
	camera   = comp(Camera3D)
	rp       = singletons(renderer)[1]

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
	separate_entities  = indices(renderer)[3]
	instanced_entities = indices(renderer)[4]
	render_separate  = !isempty(separate_entities)
	render_instanced = !isempty(instanced_entities)
	function renderall_separate()
		#render all separate ones first
		for i in separate_entities
			evao   = vao[i]
			if evao.visible
				ufunc(i)
				GLA.bind(evao)
				GLA.draw(evao)
			end
		end
	end

	function renderall_instanced()
		for evao in ivao.shared
			if evao.visible
				GLA.bind(evao)
				GLA.draw(evao)
			end
		end
	end

	function render_start(prog, renderfunc)
	    bind(prog)
	    for i in indices(renderer)[1]
		    set_uniform(prog, light[i], ucolor[i], spatial[i])
	    end
	    for i in indices(renderer)[2]
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
    # glFlush()
end

struct TextUploader <: System
	data ::SystemData
end
TextUploader(dio::Diorama) = TextUploader(SystemData(dio, (Text, Vao{TextProgram}), (RenderProgram{TextProgram}, FontStorage)))
system_data(t::TextUploader) = t.data

function update_indices!(sys::TextUploader)
	comp(T) = component(sys, T)
	text = comp(Text)
	vao  = comp(Vao{TextProgram})
	sys.data.indices = [setdiff(valid_entities(text), valid_entities(vao))]
end


function update(sys::TextUploader)
	comp(T) = component(sys, T)
	text = comp(Text)
	vao  = comp(Vao{TextProgram})
	prog = singleton(sys, RenderProgram{TextProgram})
	for e in indices(sys)[1]
		space_o_wh, uv_offset_width  = to_gl_text(text[e], singleton(sys, FontStorage))
		vao[e] = Vao{TextProgram}(VertexArray([generate_buffers(prog.program,
		                                                        GEOMETRY_DIVISOR,
		                                                        uv=Vec2f0.([(0, 1),
		                                                                    (0, 0),
		                                                                    (1, 1),
		                                                                    (1,0)]));
                                               generate_buffers(prog.program,
                                                                GLint(1),
                                                                space_o_wh      = space_o_wh,
                                                                uv_offset_width = uv_offset_width)],
                                               collect(0:3), GL_TRIANGLE_STRIP, length(text[e].str)), true)
	end
end

to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t.str, t.font_size, t.font, t.align, storage)

function to_gl_text(string::AbstractString, textsize::Int, font::Vector{Ptr{AP.FreeType.FT_FaceRec}}, align::Symbol, storage::FontStorage )
    atlas           = storage.atlas
    rscale          = Float32(textsize)
    chars           = Vector{Char}(string)
    scale           = Vec2f0.(AP.glyph_scale!.(Ref(atlas), chars, (font,), rscale))
    positions2d     = AP.calc_position(string, Point2f0(0), rscale, font, atlas)
    # font is Vector{FreeType.NativeFont} so we need to protec
    aoffset         = AbstractPlotting.align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)
    uv_offset_width = AP.glyph_uv_width!.(Ref(atlas), chars, (font,))
    out_uv_offset_width= Vec4f0[]
    for uv in uv_offset_width
	    push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3] - uv[1], uv[4] - uv[2]))
    end
    out_pos_scale = Vec4f0[]
    for (p, sc) in zip(positions2d .+ (aoffset,), scale)
	    push!(out_pos_scale, Vec4f0(p[1], p[2], sc[1], sc[2]))
    end
    return out_pos_scale, out_uv_offset_width
end

struct TextRenderer <: AbstractRenderSystem
	data ::SystemData
end
TextRenderer(dio::Diorama) = TextRenderer(SystemData(dio, (Spatial, UniformColor, Camera3D, Vao{TextProgram}), (RenderProgram{TextProgram}, RenderTarget{IOTarget}, FontStorage)))
system_data(t::TextRenderer) = t.data

function update_indices!(sys::TextRenderer)
	comp(T) = component(sys, T)
	sys.data.indices = [valid_entities(comp(Vao{TextProgram}), comp(Spatial), comp(UniformColor))]
end

function update(renderer::TextRenderer)
	comp(T)   = component(renderer, T)
	spat      = comp(Spatial)
	col       = comp(UniformColor)
	prog      = singleton(renderer, RenderProgram{TextProgram})
	cam       = comp(Camera3D)
	vao       = comp(Vao{TextProgram})
	iofbo     = singleton(renderer, RenderTarget{IOTarget})
	persp_mat = cam[valid_entities(cam)[1]].projview
	wh = size(iofbo)
	# glEnable(GL_DEPTH_TEST)
	# glDepthFunc(GL_ALWAYS)
	glEnable(GL_BLEND)
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	glyph_fbo = singleton(renderer, FontStorage).storage_fbo
	bind(color_attachment(glyph_fbo, 1))
    bind(iofbo)
    draw(iofbo)

	bind(prog)
	set_uniform(prog, :canvas_dims, Vec2f0(wh))
    set_uniform(prog, :projview, persp_mat)
	set_uniform(prog, :glyph_texture, (0, color_attachment(glyph_fbo, 1)))
	for e in indices(renderer)[1]
		set_uniform(prog, :start_pos, spat[e].position)
		set_uniform(prog, :color, col[e].color)
		bind(vao[e])
		# @show vao[e].vertexarray.indices
		draw(vao[e])
	end
	# unbind(prog)
end

struct FinalRenderer <: AbstractRenderSystem
	data ::SystemData
end
FinalRenderer(dio::Diorama) = FinalRenderer(SystemData(dio, (), (RenderPass{FinalPass}, Canvas, RenderTarget{IOTarget}, FullscreenVao)))

system_data(f::FinalRenderer) = f.data

function update(sys::FinalRenderer)
    rp                  = singleton(sys, RenderPass{FinalPass})
    compositing_program = main_program(rp)
    canvas              = singleton(sys, Canvas)
    vao                 = singleton(sys, FullscreenVao)
    iofbo               = singleton(sys, RenderTarget{IOTarget})
    bind(canvas)
    draw(canvas)
    # clear!(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 1)))
    bind(vao)
    draw(vao)
end
