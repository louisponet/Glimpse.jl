struct FinalRenderer <: AbstractRenderSystem
	compositing_program ::GLA.Program
    FinalRenderer() = new(Program(compositing_shaders()))
end
requested_components(::FinalRenderer) = (Canvas, FullscreenVao, RenderTarget{IOTarget})

function (x::FinalRenderer)(m)

    compositing_program = x.compositing_program
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
