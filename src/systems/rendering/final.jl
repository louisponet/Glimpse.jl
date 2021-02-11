@render_program FXAAProgram
@render_program CompositingProgram

struct FinalRenderer <: AbstractRenderSystem end

Overseer.requested_components(::FinalRenderer) = (Canvas, FullscreenVao, FXAAProgram, CompositingProgram, IOTarget)

function Overseer.prepare(::FinalRenderer, dio::Diorama)
    e = Entity(dio[DioEntity], 1)
	if isempty(dio[CompositingProgram])
		dio[e] = CompositingProgram(Program(compositing_shaders()))
	end
	if isempty(dio[FXAAProgram])
    	dio[e] = FXAAProgram(Program(fxaa_shaders()))
	end
end

function Overseer.update(::FinalRenderer, m::AbstractLedger)
    compositing_program = singleton(m, CompositingProgram)
    fxaa_program        = singleton(m, FXAAProgram)
    canvas              = singleton(m, Canvas)
    vao                 = singleton(m, FullscreenVao)
    iofbo               = singleton(m, IOTarget)
    bind(iofbo)
    bind(canvas)
    clear!(canvas)
    draw(canvas)

    # glDepthMask(GL_TRUE)
    # bind(fxaa_program)
    # gluniform(fxaa_program, :color_texture, 0, color_attachment(iofbo.target, 1))
    # gluniform(fxaa_program, :frameBufSize, Vec2f0(size(iofbo)...))
    # gluniform(fxaa_program, :RCPFrame, Vec2f0((1 ./ size(iofbo))...))
    bind(compositing_program)
    gluniform(compositing_program, :color_texture, 0, color_attachment(iofbo.target, 1))
    bind(vao)
    draw(vao)
end
