import GLAbstraction: gluniform, bind, set_uniform

#TODO only allows for one light at this point!
function (rp::RenderPass{:default})(scene::Scene)
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
        set_uniform(program, Symbol("plight.diff_intensity"), l.diffuse)
    end

    for renderable in scene.renderables
        if !in(:default, renderable.renderpasses)
            continue
        end
        bind(renderable)
        for (key, val) in renderable.uniforms
            set_uniform(program, key, val)
        end
        draw(renderable)
        unbind(renderable) #not sure why this is necessary
    end
end
