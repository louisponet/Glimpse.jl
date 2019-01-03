import GLAbstraction: gluniform, bind, set_uniform

function set_uniforms(program::Program, renderable::Renderable)
    for (key, val) in renderable.uniforms
        set_uniform(program, key, val)
    end
end

function render(rp::Renderpass{T}, renderable::Renderable) where T
    if !in(T, renderable.renderpasses)
        return
    end
    bind(renderable)
    set_uniforms(rp.program, renderable)
    draw(renderable)
    unbind(renderable)
end

#TODO only allows for one light at this point!
function (rp::Renderpass{:default})(scene::Scene)
    program = rp.program
    if isempty(scene.renderables)
        return
    end

    set_uniform(program, :projview, projviewmat(scene))
    set_uniform(program, :campos, scene.camera.eyepos)
    if !isempty(scene.lights)
        l = scene.lights[1]
        set_uniform(program, Symbol("plight.color"), l.color)
        set_uniform(program, Symbol("plight.position"), l.position)
        set_uniform(program, Symbol("plight.amb_intensity"), l.ambient)
        set_uniform(program, Symbol("plight.specular_intensity"), l.specular)
        set_uniform(program, Symbol("plight.diff_intensity"), l.diffuse)
    end

    render.((rp,), scene.renderables)
end

function (rp::Renderpass{:cheap_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    rp_renderables = filter(x -> in(:transparency, x.renderpasses), scene.renderables)
    f = 0.75
    program = rp.program
    set_uniform(program, :projview, projviewmat(scene))
    set_uniform(program, :campos, scene.camera.eyepos)
    if !isempty(scene.lights)
        l = scene.lights[1]
        set_uniform(program, Symbol("plight.color"), l.color)
        set_uniform(program, Symbol("plight.position"), l.position)
        set_uniform(program, Symbol("plight.specular_intensity"), l.specular)
        set_uniform(program, Symbol("plight.amb_intensity"), l.ambient)
        set_uniform(program, Symbol("plight.diff_intensity"), l.diffuse)
    end
    function render_with_alpha(alphafunc)
        for renderable in rp_renderables
            bind(renderable)
            set_uniforms(rp.program, renderable)
            set_uniform(rp.program, :alpha, alphafunc(renderable.uniforms[:alpha]))
            draw(renderable)
            unbind(renderable)
        end
    end
    glDisable(GL_CULL_FACE)
    glDepthFunc(GL_LESS)
    render_with_alpha(x -> 0f0)
    #
    glEnable(GL_CULL_FACE)
    glCullFace(GL_FRONT)
    glDepthFunc(GL_ALWAYS)
    render_with_alpha(x ->f * x)
    # #
    glEnable(GL_CULL_FACE)
    glCullFace(GL_FRONT)
    glDepthFunc(GL_LEQUAL)
    render_with_alpha(x -> (x - f*x)/(1.0 - f*x))

    glEnable(GL_CULL_FACE)
    glCullFace(GL_BACK)
    glDepthFunc(GL_ALWAYS)
    render_with_alpha(x -> f*x)

    glDisable(GL_CULL_FACE)
    glDepthFunc(GL_LEQUAL)
    render_with_alpha(x -> (x-f*x)/(1.0-f*x))
    glDisable(GL_BLEND)
end
function (rp::Renderpass{:simple_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    program = rp.program
    set_uniform(program, :projview, projviewmat(scene))
    set_uniform(program, :campos, scene.camera.eyepos)
    if !isempty(scene.lights)
        l = scene.lights[1]
        set_uniform(program, Symbol("plight.color"), l.color)
        set_uniform(program, Symbol("plight.position"), l.position)
        set_uniform(program, Symbol("plight.specular_intensity"), l.specular)
        set_uniform(program, Symbol("plight.amb_intensity"), l.ambient)
        set_uniform(program, Symbol("plight.diff_intensity"), l.diffuse)
    end
    render.((rp,), scene.renderables)
end

function(rp::Renderpass{:depth_peeling_transparancy})(scene::Scene)

end
