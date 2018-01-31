import GLAbstraction: RenderPass

function (rp::RenderPass{:default})(scene::Scene)
    clear!(current_context())
    if isempty(scene.renderables)
        return
    end
    for renderable in scene.renderables
        bind(renderable)
        draw(renderable)
    end
    unbind(scene.renderables[1])
end