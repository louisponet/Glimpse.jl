struct FinalRenderer <: AbstractRenderSystem
	data                ::SystemData
	compositing_program ::GLA.Program

    FinalRenderer(dio::Diorama) = new(SystemData(dio, (), (Canvas, RenderTarget{IOTarget}, FullscreenVao)),
                                      Program(compositing_shaders()))
end

function update(sys::FinalRenderer)
    compositing_program = sys.compositing_program
    canvas              = singleton(sys, Canvas)
    vao                 = singleton(sys, FullscreenVao)
    iofbo               = singleton(sys, RenderTarget{IOTarget})
    bind(canvas)
    draw(canvas)
    bind(compositing_program)
    set_uniform(compositing_program, :color_texture, (0, color_attachment(iofbo.target, 1)))
    bind(vao)
    draw(vao)
end
