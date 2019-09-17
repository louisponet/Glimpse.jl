struct CompositingProgram <: ProgramKind end

struct FinalRenderer <: AbstractRenderSystem end

requested_components(::FinalRenderer) = (Canvas, FullscreenVao, RenderProgram{CompositingProgram}, RenderTarget{IOTarget})

function ECS.prepare(::FinalRenderer, dio::Diorama)
	if isempty(dio[RenderProgram{CompositingProgram}])
		Entity(dio, RenderProgram{CompositingProgram}(Program(compositing_shaders())))
	end
end

function update(::FinalRenderer, m::Manager)

    compositing_program = m[RenderProgram{CompositingProgram}][1]
    canvas              = m[Canvas][1]
    vao                 = m[FullscreenVao][1]
    iofbo               = m[RenderTarget{IOTarget}][1]
    bind(canvas)
    draw(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 1)))
    bind(vao)
    draw(vao)
end
