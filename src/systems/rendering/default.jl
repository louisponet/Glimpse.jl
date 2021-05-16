import GLAbstraction: gluniform

@render_program DefaultProgram
@render_program InstancedDefaultProgram

@vao DefaultVao
@instanced_vao InstancedDefaultVao

struct DefaultRenderer <: AbstractRenderSystem end

Overseer.requested_components(::DefaultRenderer) =
    (DefaultVao, DefaultProgram, InstancedDefaultVao, InstancedDefaultProgram,
     ModelMat, Material, PointLight, UniformColor, BufferColor, Spatial, Camera3D, IOTarget)

function Overseer.update(::DefaultRenderer, m::AbstractLedger)
    fbo   = singleton(m, IOTarget)
    prog  = singleton(m, DefaultProgram)
    iprog = singleton(m, InstancedDefaultProgram)

    bind(fbo)
    draw(fbo)
    glDisable(GL_BLEND)
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    glEnableCullFace(:back)
    #Render instanced-renderables

    bind(prog)

    light, ucolor, spat, cam, modelmat, material, vao =
        m[PointLight], m[UniformColor],  m[Spatial], m[Camera3D], m[ModelMat], m[Material], m[DefaultVao]

    set_light_camera_uniforms = (prog) -> begin
        for e in @entities_in(m, PointLight  && UniformColor && Spatial)
            gluniform(prog, e[PointLight], e[UniformColor], e[Spatial])
        end

        for e in @entities_in(spat && cam)
            gluniform(prog, spat[e], cam[e])
        end
    end
    set_light_camera_uniforms(prog)

    set_model_material = (e_modelmat, e_material) -> begin
        gluniform(prog, :material, Vec2(e_material.specpow, e_material.specint))
        gluniform(prog, :modelmat, e_modelmat.modelmat)
    end

    #Colors inside Vao
    for e in @entities_in(vao && modelmat && material && !ucolor)
        evao = vao[e]
        if evao.visible
            set_model_material(modelmat[e], material[e])
            if e in idcolor
                gluniform(prog, :object_id_color, idcolor[e].color)
            end
            GLA.bind(evao)
            GLA.draw(evao)
        end
    end

    bind(iprog)
    set_light_camera_uniforms(iprog)
    ivao = m[InstancedDefaultVao]
    for evao in ivao.shared
        if evao.visible
            GLA.bind(evao)
            GLA.draw(evao)
        end
    end
end
