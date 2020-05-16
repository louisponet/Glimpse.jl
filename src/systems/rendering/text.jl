@render_program TextProgram
@vao TextVao

struct TextUploader <: System end
Overseer.requested_components(::TextUploader) = (Text, TextVao, TextProgram, FontStorage)

function Overseer.prepare(::TextUploader, dio::Diorama)
	if isempty(dio[TextProgram])
		dio[Entity(1)] = TextProgram(Program(text_shaders()))
	end
	if isempty(dio[FontStorage])
		dio[Entity(1)] =  FontStorage()
	end
end

function Overseer.update(::TextUploader, m::AbstractLedger)
	text = m[Text]
	vao  = m[TextVao]
	prog = m[TextProgram][1]
	ucolor = m[UniformColor]
	spatial= m[Spatial]
	fontstorage = m[FontStorage][1]

	for e in @entities_in(text && spatial && ucolor)
    	t=text[e]
		offset_width, uv_texture_bbox  = to_gl_text(t, fontstorage)
		nsprites = length(t.str)
		if !(e ∈ vao) || nsprites > length(vao[e])
    		vao[e] = TextVao(VertexArray(generate_buffers(prog.program,
                                   GLint(0),
                                   color = fill(ucolor[e].color, nsprites),
                                   rotation = fill(Vec4f0(0), nsprites),
                                   offset_width    = offset_width,
                                   uv_texture_bbox = uv_texture_bbox), GL_POINTS), true)
        else
            GLA.upload!(vao[e], color       = fill(ucolor[e].color, nsprites),
                            rotation        = fill(Vec4f0(0), nsprites),
                            offset_width    = offset_width,
                            uv_texture_bbox = uv_texture_bbox)
        end
	end
end

to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t.str, t.font_size, t.font, t.align, storage)

function to_gl_text(string::AbstractString, textsize, font, align::Symbol, storage::FontStorage)
    atlas           = storage.atlas
    rscale          = Float32(textsize)
    chars           = Vector{Char}(string)
    scale           = Vec2f0.(AP.glyph_scale!.(Ref(atlas), chars, (font,), rscale))
    positions2d     = AP.calc_position(string, Point2f0(0), rscale, font, atlas)

    aoffset         = AbstractPlotting.align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)
    uv_offset_width = AP.glyph_uv_width!.(Ref(atlas), chars, (font,))
    out_uv_offset_width= Vec4f0[]
    for uv in uv_offset_width
	    push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3], uv[4] ))
    end
    out_pos_scale = Vec4f0[]
    for (p, sc) in zip(positions2d .+ (aoffset,), scale)
	    push!(out_pos_scale, Vec4f0(p[1], p[2], sc[1], sc[2]))
    end
    return out_pos_scale, out_uv_offset_width
end

struct TextRenderer <: AbstractRenderSystem end

Overseer.requested_components(::TextRenderer) =
	(Spatial, UniformColor, Camera3D, TextVao, Text,
		TextProgram, IOTarget, FontStorage)

function Overseer.update(::TextRenderer, m::AbstractLedger)
	spat           = m[Spatial]
	prog           = singleton(m, TextProgram)
	camera         = singleton(m, Camera3D)
	vao            = m[TextVao]
	iofbo          = singleton(m, IOTarget)
	persp_mat      = camera.projview
	projection_mat = camera.proj
	text           = m[Text]
	wh = size(iofbo)

	glDisable(GL_DEPTH_TEST)
	glDepthFunc(GL_ALWAYS)
	glDisableCullFace()

	glyph_fbo = singleton(m, FontStorage).storage_fbo
	bind(color_attachment(glyph_fbo, 1))
    bind(iofbo)
    draw(iofbo)

	bind(prog)
	set_uniform(prog, :resolution, Vec2f0(wh))
    set_uniform(prog, :projview, persp_mat)
    set_uniform(prog, :projection, projection_mat)

    # Fragment uniforms
	set_uniform(prog, :distancefield, 0, color_attachment(glyph_fbo, 1))
	set_uniform(prog, :shape, 3)
	#TODO make this changeable
	set_uniform(prog, :stroke_width, 0f0)
	set_uniform(prog, :glow_width, 0f0)
	set_uniform(prog, :billboard, true)
	set_uniform(prog, :scale_primitive,false)
	for e in @entities_in(vao && spat && text)
        e_vao, e_spat, e_text = vao[e], spat[e], text[e]
        if e_vao.visible
    		set_uniform(prog,:model, m[ModelMat][e].modelmat)
    		set_uniform(prog,:origin, e_text.offset)
    		bind(e_vao)
    		draw(e_vao)
		end
	end
end

