@render_program CompositingProgram

struct FinalRenderer <: AbstractRenderSystem end

ECS.requested_components(::FinalRenderer) = (Canvas, FullscreenVao, CompositingProgram, IOTarget)

function ECS.prepare(::FinalRenderer, dio::Diorama)
	if isempty(dio[CompositingProgram])
		dio[Entity(1)] = CompositingProgram(Program(compositing_shaders()))
	end
end

function ECS.update(::FinalRenderer, m::AbstractManager)
    compositing_program = m[CompositingProgram][1]
    canvas              = m[Canvas][1]
    vao                 = m[FullscreenVao][1]
    iofbo               = m[IOTarget][1]
    bind(canvas)
    draw(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 1)))
    bind(vao)
    draw(vao)
end
