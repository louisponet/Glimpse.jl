#!/home/ponet/bin/julia
#%%
using Revise
using Glimpse
const Gl = Glimpse
import Glimpse: SystemKind, System, Component, ComponentData, update, Spatial, TimingData, valid_entities, singleton, component, RGBAf0, component, system, DefaultRenderer, Vao, DefaultProgram, shared_component, ProgramTag
using GLFW
using ModernGL
using LinearAlgebra
using Debugger
using JuliaInterpreter
using TimerOutputs; 
using Profile, ProfileView
using AbstractPlotting
const AP = AbstractPlotting
using FreeTypeAbstraction
using UnicodePlots
using GLAbstraction
const GLA = GLAbstraction
#%%
dio = Diorama(background=RGBAf0(1.0,1.0,1.0,1.0));
Gl.new_entity!(dio, separate=[Gl.Text(), Gl.Spatial(), Gl.UniformColor(RGBAf0(1.0, 0.0,0.0,1.0))])
Gl.update_system_indices!(dio)
dio.loop = Gl.renderloop(dio)
Gl.close(dio)
#%%
# using AbstractPlotting: get_texture_atlas, glyph_bearing!, glyph_uv_width!, glyph_scale!, calc_position, calc_offset, broadcast_foreach, NativeFont, to_font

# function to_gl_text(string, startpos::Vec3f0, textsize, font, align) where {N, T}
#     atlas           = get_texture_atlas()
#     rscale          = Float32(textsize)
#     chars           = Vector{Char}(string)
#     scale           = Gl.Vec2f0.(glyph_scale!.(Ref(atlas), chars, (font,), rscale))
#     positions2d     = calc_position(string, Point2f0(0), rscale, font, atlas)
#     # font is Vector{FreeType.NativeFont} so we need to protec
#     aoffset         = AbstractPlotting.align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)
#     aoffsetn        = to_ndim(Point{3, Float32}, aoffset, 0f0)
#     uv_offset_width = glyph_uv_width!.(Ref(atlas), chars, (font,))

#     positions = map(positions2d) do p
#         pn          =to_ndim(Point{3, Float32}, p, 0f0) .+ aoffsetn
#         pn .+ startpos
#     end

#     positions, Vec2f0(0), uv_offset_width, scale
# end
# #%%
# dio = Diorama(background=RGBAf0(0.0,0.0,0.0,1.0));
# wh = Gl.pixelsize(dio)
# projview = Gl.projmatortho(Float32, 0.0, wh[1], 0.0, wh[2])
# positions, d, uv_offset_width, scale = to_gl_text("test", Vec3f0(wh[1]/2, wh[2]/2, 0.0), 50, AP.defaultfont(), :right)
# # uv_offset_width
# using FileIO
# prog = GLA.Program([load("Glimpse/src/shaders/text.vert"), load("Glimpse/src/shaders/text.frag")])
# GLA.bind(prog)

# vertices_loc = GLA.attribute_location(prog, :vertices) 
# uv_loc       = GLA.attribute_location(prog, :uv)
# color_loc    = GLA.attribute_location(prog, :color)

# vaos = GLA.VertexArray[]
# color = RGBAf0(1.0, 0.0, 1.0, 1.0)
# for (p, uv_o_w, sc) in zip(positions, uv_offset_width, scale)
# 	tobuf = [Vec4f0(p[1], p[2] + sc[2]    , uv_o_w[1], uv_o_w[2]),
#              Vec4f0(p[1], p[2]            , uv_o_w[1], uv_o_w[4]),
#              Vec4f0(p[1]+sc[1], p[2]+sc[2], uv_o_w[3], uv_o_w[2]),
#              Vec4f0(p[1]+sc[1], p[2]      , uv_o_w[3], uv_o_w[4])]

# 	vertices = GLA.Buffer(tobuf)
# 	c = GLA.Buffer([color, color, color, color])
# 	push!(vaos, GLA.VertexArray([GLA.BufferAttachmentInfo(:vert_uv,
# 														  GLint(0),
# 														  vertices,
# 														  GLA.GEOMETRY_DIVISOR),
#      		                     GLA.BufferAttachmentInfo(:color,
#  		                     							  GLint(1),
#      		                     						  c,
#      		                     						  GLA.GEOMETRY_DIVISOR)], 5))
# end

# # glEnable(GL_CULL_FACE)
# glEnable(GL_BLEND)
# Gl.glDisableDepth()
# Gl.glBlendFunc(Gl.GL_SRC_ALPHA, Gl.GL_ONE_MINUS_SRC_ALPHA);
# atlas = get_texture_atlas()
# glViewport(0, 0, wh[1], wh[2])
# fbo = GLA.FrameBuffer(size(atlas.data), (eltype(atlas.data), ),[atlas.data])
# GLA.unbind(fbo)
# canvas = Gl.singleton(dio, Gl.Canvas)
# xoffset = 0.0f0
# while !Gl.should_close(canvas)
# 	# global xoffset += 1.0f0
#     Gl.bind(canvas)
#     Gl.draw(canvas)
#     Gl.clear!(canvas)
# 	Gl.pollevents(canvas)
# 	wh = Gl.pixelsize(dio)
# 	GLA.bind(prog)
# 	vao = Gl.singleton(dio, Gl.FullscreenVao)
# 	GLA.bind(fbo.attachments[1])
# 	GLA.set_uniform(prog, :glyph_texture, (0, Gl.color_attachment(fbo, 1)))
# 	Gl.set_uniform(prog, :canvas_width, wh[1])
# 	Gl.set_uniform(prog, :canvas_height, wh[2])
# 	for v in vaos
# 		GLA.bind(v)
# 		GLA.draw(v)
# 	end
# 	glUseProgram(0)
# 	Gl.swapbuffers(canvas)
# 	sleep(0.01)
# end
# Gl.close(dio)


#%%


# @run update(system(dio, Gl.Mesher))
#%%
#   pGLFW.DestroyWindow(GLFW.GetCurrentContext())

#%%
# face = newface("/home/ponet/.local/share/fonts/FiraCode-Regular.ttf")


# myarray = zeros(UInt16, 1920, 1080)
# renderstring!(myarray, "hello", face, (100, 1000), 90, 10, halign=:right)
# myarray[10:end,10:end]


# myarray[90:end,10:end]
# spy(myarray)
# text = GLA.Texture()

#%%
# atlas = AP.get_texture_atlas();
# AP.glyph_uv_width!(atlas, 'c', AP.defaultfont())

# # #%%
# Gl.GLFW.Terminate()
# Gl.GLFW.Init()
# dio = Diorama();
# wh = Gl.singleton(dio, Gl.Canvas).area.w, Gl.singleton(dio, Gl.Canvas).area.h
# fbo = GLA.FrameBuffer(size(atlas.data), (eltype(atlas.data), ),[atlas.data])
# vao = Gl.singleton(dio, Gl.FullscreenVao)
# prog = Gl.singleton(dio, Gl.RenderPass{Gl.DepthPeelingPass}).programs[:composite]
# while true
# 	GLA.bind(prog)
# 	GLA.set_uniform(prog, :color_texture, (0, GLA.color_attachment(fbo, 1)))
# 	GLA.bind(vao)
# 	GLA.draw(vao)
# 	Gl.swapbuffers(Gl.singleton(dio, Gl.Canvas))
# 	sleep(0.01)
# end
#%%
# GLA.bind(fbo)
# gpu_data(fbo.attachments[1])
# GLA.bind(fbo.attachments[1])
# testarr = zeros(Float16, size(fbo.attachments[1]))
# GLA.glGetTexImage(fbo.attachments[1].texturetype, 0, fbo.attachments[1].format, fbo.attachments[1].pixeltype, testarr)

#%%
Gl.GLFW.Terminate()
Gl.GLFW.Init()
#%%
