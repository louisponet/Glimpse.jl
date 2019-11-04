@render_program CompositingProgram

struct FinalRenderer <: AbstractRenderSystem end

Overseer.requested_components(::FinalRenderer) = (Canvas, FullscreenVao, CompositingProgram, IOTarget)

function Overseer.prepare(::FinalRenderer, dio::Diorama)
	if isempty(dio[CompositingProgram])
		dio[Entity(1)] = CompositingProgram(Program(compositing_shaders()))
	end
end

function Overseer.update(::FinalRenderer, m::AbstractLedger)
    compositing_program = singleton(m, CompositingProgram)
    canvas              = singleton(m, Canvas)
    vao                 = singleton(m, FullscreenVao)
    iofbo               = singleton(m, IOTarget)
    bind(iofbo)
    bind(canvas)
    clear!(canvas)
    draw(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 2)))
    bind(vao)
    draw(vao)
end
