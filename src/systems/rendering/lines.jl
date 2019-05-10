struct LineProgram <: ProgramKind end

LinesUploader(dio::Diorama) = Uploader(LineProgram,    dio)

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

# For Line rendering see default.jl. Lines are currently rendered by the Default renderer 
