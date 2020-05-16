struct PreRenderer <: AbstractRenderSystem end

function Overseer.update(::PreRenderer, m::AbstractLedger)
    glEnable(GL_STENCIL_TEST)
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
    glStencilMask(0xff)
    glClearStencil(0)
end
