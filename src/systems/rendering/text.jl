struct TextProgram <: ProgramKind end

# struct TextUploader <: System
# 	data ::SystemData

# 	TextUploader(dio::Diorama) =
# 		new(SystemData(dio, (Text, Vao{TextProgram}), (RenderProgram{TextProgram}, FontStorage)))
# end


# function update_indices!(sys::TextUploader)
# 	comp(T) = component(sys, T)
# 	text = comp(Text)
# 	vao  = comp(Vao{TextProgram})
# 	sys.data.indices = [setdiff(valid_entities(text), valid_entities(vao))]
# end


# function update(sys::TextUploader)
# 	comp(T) = component(sys, T)
# 	text = comp(Text)
# 	vao  = comp(Vao{TextProgram})
# 	prog = singleton(sys, RenderProgram{TextProgram})
# 	for e in indices(sys)[1]
# 		space_o_wh, uv_offset_width  = to_gl_text(text[e], singleton(sys, FontStorage))
# 		vao[e] = Vao{TextProgram}(VertexArray([generate_buffers(prog.program,
# 		                                                        GEOMETRY_DIVISOR,
# 		                                                        uv=Vec2f0.([(0, 1),
# 		                                                                    (0, 0),
# 		                                                                    (1, 1),
# 		                                                                    (1,0)]));
#                                                generate_buffers(prog.program,
#                                                                 GLint(1),
#                                                                 space_o_wh      = space_o_wh,
#                                                                 uv_offset_width = uv_offset_width)],
#                                                collect(0:3), GL_TRIANGLE_STRIP, length(text[e].str)), true)
# 	end
# end

# to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t.str, t.font_size, t.font, t.align, storage)

# function to_gl_text(string::AbstractString, textsize::Int, font::Vector{Ptr{AP.FreeType.FT_FaceRec}}, align::Symbol, storage::FontStorage)
#     atlas           = storage.atlas
#     rscale          = Float32(textsize)
#     chars           = Vector{Char}(string)
#     scale           = Vec2f0.(AP.glyph_scale!.(Ref(atlas), chars, (font,), rscale))
#     positions2d     = AP.calc_position(string, Point2f0(0), rscale, font, atlas)

#     aoffset         = AbstractPlotting.align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)
#     uv_offset_width = AP.glyph_uv_width!.(Ref(atlas), chars, (font,))
#     out_uv_offset_width= Vec4f0[]
#     for uv in uv_offset_width
# 	    push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3] - uv[1], uv[4] - uv[2]))
#     end
#     out_pos_scale = Vec4f0[]
#     for (p, sc) in zip(positions2d .+ (aoffset,), scale)
# 	    push!(out_pos_scale, Vec4f0(p[1], p[2], sc[1], sc[2]))
#     end
#     return out_pos_scale, out_uv_offset_width
# end

# struct TextRenderer <: AbstractRenderSystem
# 	data ::SystemData

# 	function TextRenderer(dio::Diorama)
# 		components = (Spatial, UniformColor, Camera3D, Vao{TextProgram}, Text)
# 		singletons = (RenderProgram{TextProgram}, RenderTarget{IOTarget}, FontStorage)
# 		new(SystemData(dio, components, singletons))
# 	end
# end

# function update_indices!(sys::TextRenderer)
# 	comp(T) = component(sys, T)
# 	sys.data.indices = [valid_entities(comp(Vao{TextProgram}), comp(Spatial), comp(UniformColor))]
# end

# function update(renderer::TextRenderer)
# 	comp(T)   = component(renderer, T)
# 	spat      = comp(Spatial)
# 	col       = comp(UniformColor)
# 	prog      = singleton(renderer, RenderProgram{TextProgram})
# 	cam       = comp(Camera3D)
# 	vao       = comp(Vao{TextProgram})
# 	iofbo     = singleton(renderer, RenderTarget{IOTarget})
# 	persp_mat = cam[valid_entities(cam)[1]].projview
# 	text      = comp(Text)
# 	wh = size(iofbo)

# 	glEnable(GL_DEPTH_TEST)
# 	glDepthFunc(GL_LEQUAL)

# 	glyph_fbo = singleton(renderer, FontStorage).storage_fbo
# 	bind(color_attachment(glyph_fbo, 1))
#     bind(iofbo)
#     draw(iofbo)

# 	bind(prog)
# 	set_uniform(prog, :canvas_dims, Vec2f0(wh))
#     set_uniform(prog, :projview, persp_mat)
# 	set_uniform(prog, :glyph_texture, (0, color_attachment(glyph_fbo, 1)))
# 	for e in indices(renderer)[1]
# 		set_uniform(prog, :start_pos, spat[e].position + text[e].offset)
# 		set_uniform(prog, :color, col[e].color)
# 		bind(vao[e])
# 		draw(vao[e])
# 	end
# end

