import GLAbstraction: RenderPass
import GLAbstraction: gluniform
function (rp::RenderPass{:default})(scene::Scene)
    clear!(current_context())
    proj = projmat(scene)
    view = lookatmat(Vec3((-3f0, 0f0, -3f0)), Vec3((0f0, 0f0, 0f0)), Vec3((0f0, 0f0, 1f0)))
    proj = projmatpersp(45f0, 800f0/600f0, 0.1f0, 100f0)
    # projview = Mat4f0(zeros(4,4))
    # projview = proj*rot*view
    # projview = view' * proj'
    # projview = Eye4f0()
    # view = transmat(Vec3f0(0,0,rand(0:1)))
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
    end
    unbind(scene.renderables[1])
end
