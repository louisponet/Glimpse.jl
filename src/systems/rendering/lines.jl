@render_program LineProgram
@vao LineVao

LineUploader() = Uploader{LineProgram}()
shaders(::Type{LineProgram}) = line_shaders()

function set_entity_uniforms_func(render_program::LineProgram, system::System)
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

ECS.requested_components(::LineRenderer) =
	(LineVao, LineProgram,
	 ModelMat, Material, PointLight, Spatial, Camera3D, IOTarget, LineOptions)

function ECS.update(::LineRenderer, m::AbstractManager)
	fbo  = m[IOTarget][1]
	prog = m[LineProgram][1]
	bind(fbo)
	draw(fbo)
	glDisable(GL_BLEND)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	bind(prog)
    light, ucolor, spat, modelmat, cam =
        m[PointLight], m[UniformColor], m[Spatial], m[ModelMat], m[Camera3D]
    for e in @entities_in(light && ucolor && spat)
	    set_uniform(prog, light[e], ucolor[e], spat[e])
    end
    for e in @entities_in(spat && cam)
	    set_uniform(prog, spat[e], cam[e])
    end
	set_uniform(prog, :Viewport, Vec2f0(size(m[IOTarget][1])))
    vao, modelmat, line = m[LineVao], m[ModelMat], m[LineOptions] 
	for e in @entities_in(vao && modelmat && line)
        evao = vao[e]
        e_line = line[e]
		if evao.visible
			set_uniform(prog, :modelmat,   modelmat[e].modelmat)
			set_uniform(prog, :thickness,  e_line.thickness)
			set_uniform(prog, :MiterLimit, e_line.miter)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end
