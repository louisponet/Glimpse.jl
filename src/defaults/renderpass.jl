import GLAbstraction: RenderPass
import GLAbstraction: gluniform
function (rp::RenderPass{:default})(scene::Scene)
    clear!(current_context())
    proj = projmat(scene)
    view = viewmat(scene)
    glDisable(GL_CULL_FACE)
    if haskey(rp.program.uniformloc, :proj)
        gluniform(rp.program.uniformloc[:proj][1], proj)
    end

    if haskey(rp.program.uniformloc, :view)
        gluniform(rp.program.uniformloc[:view][1], view)
    end
    if isempty(scene.renderables)
        return
    end
    for renderable in scene.renderables
        bind(renderable)
        draw(renderable)
        unbind(renderable) #not sure why this is necessary
    end
    unbind(scene.renderables[1])
end
