import GLAbstraction: RenderPass
import GLAbstraction: gluniform, attributes_info

#TODO only allows for one light at this point!
function (rp::RenderPass{:default})(scene::Scene)
    if isempty(scene.renderables)
        return
    end

    projview = projviewmat(scene)
    if haskey(rp.program.uniformloc, :projview)
        gluniform(rp.program.uniformloc[:projview][1], projview)
    end

    if haskey(rp.program.uniformloc, Symbol("plight.color")) && !isempty(scene.lights)
        l = scene.lights[1]
        gluniform(rp.program.uniformloc[Symbol("plight.color")][1], l.color)
        gluniform(rp.program.uniformloc[Symbol("plight.position")][1], l.position)
        gluniform(rp.program.uniformloc[Symbol("plight.amb_intensity")][1], l.ambient)
        gluniform(rp.program.uniformloc[Symbol("plight.diff_intensity")][1], l.diffuse)
    end

    if haskey(rp.program.uniformloc, :campos)
        gluniform(rp.program.uniformloc[:campos][1], scene.camera.eyepos)
    end

    gluniform(rp.program.uniformloc[:modelmat][1], Eye4f0())
    #TODO speed: the typechecking etc here is pretty slow, maybe it would be a good idea to upon construction assign which renderable is rendered by which pipeline.
    # attribtyps = glenum2julia.(getindex.(attributes_info(rp.program), :type))

    for renderable in scene.renderables
        if !in(:default, renderable.renderpasses)
            continue
        end
        bind(renderable)
        # rtyps = (eltype(renderable.vao)[1].parameters...)
        # if !all( sizeof.(rtyps) .== sizeof.(attribtyps))
        #     unbind(renderable)
        #     continue
        # end
        for (key, val) in renderable.uniforms
            if haskey(rp.program.uniformloc, key)
                gluniform(rp.program.uniformloc[key][1], val)
            end
        end
        draw(renderable)
        unbind(renderable) #not sure why this is necessary
    end
end
