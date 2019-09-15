struct LineProgram <: ProgramKind end

LineUploader() = Uploader{LineProgram}()
shaders(::Type{LineProgram}) = line_shaders()

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

struct LineRenderer <: AbstractRenderSystem end

requested_components(::LineRenderer) =
	(Vao{LineProgram}, RenderProgram{LineProgram},
	 ModelMat, Material, PointLight, Spatial, Camera3D, RenderTarget{IOTarget}, Line)

function (::LineRenderer)(m)
	fbo  = m[RenderTarget{IOTarget}][1]
	prog = m[RenderProgram{LineProgram}][1]
	bind(fbo)
	draw(fbo)
	glDisable(GL_BLEND)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	bind(prog)

    for (l, c, s) in zip(m[PointLight], m[UniformColor], m[Spatial])
	    set_uniform(prog, l, c, s)
    end
    for (s, c) in zip(m[Spatial], m[Camera3D])
	    set_uniform(prog, s, c)
    end
	set_uniform(prog, :Viewport, Vec2f0(size(m[RenderTarget{IOTarget}][1])))

	for (evao, e_modelmat, e_line) in zip(m[Vao{LineProgram}], m[ModelMat], m[Line])
		if evao.visible
			set_uniform(prog, :modelmat,   e_modelmat.modelmat)
			set_uniform(prog, :thickness,  e_line.thickness)
			set_uniform(prog, :MiterLimit, e_line.miter)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end
