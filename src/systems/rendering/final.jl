@render_program FXAAProgram
@render_program CompositingProgram

struct FinalRenderer <: AbstractRenderSystem end

function Overseer.requested_components(::FinalRenderer)
    return (Canvas, FullscreenVao, FXAAProgram, CompositingProgram, IOTarget)
end

function Overseer.prepare(::FinalRenderer, dio::Diorama)
    e = entity(dio[DioEntity], 1)
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
    # bind(iofbo)
    bind(canvas)
    clear!(canvas)
    draw(canvas)

    glDisable(GL_DEPTH_TEST)
    bind(fxaa_program)
    gluniform(fxaa_program, :u_colorTexture, 0, color_attachment(iofbo.target, 1))
    gluniform(fxaa_program, :u_texelStep, Vec2f0((1 ./ size(iofbo))...))

    gluniform(fxaa_program, :u_showEdges, false)
    gluniform(fxaa_program, :u_fxaaOn, true)
    gluniform(fxaa_program, :u_lumaThreshold, 0.3f0)
    gluniform(fxaa_program, :u_mulReduce, 1 / 8.0f0)
    gluniform(fxaa_program, :u_minReduce, 1 / 128.0f0)
    gluniform(fxaa_program, :u_maxSpan, 8.0f0)
    # gluniform(fxaa_program, :frameBufSize, Vec2f0(size(iofbo)...))
    # bind(compositing_program)
    # gluniform(compositing_program, :color_texture, 0, color_attachment(iofbo.target, 1))
    bind(vao)
    draw(vao)
    return glEnable(GL_DEPTH_TEST)
end
