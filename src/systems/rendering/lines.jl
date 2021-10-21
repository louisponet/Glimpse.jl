@render_program LineProgram
@vao LineVao

LineUploader() = Uploader{LineProgram}()
shaders(::Type{LineProgram}) = line_shaders()

function set_entity_uniforms_func(render_program::LineProgram, system::System)
    prog = render_program.program
    comp(T)  = component(system, T)
    modelmat = comp(ModelMat)
    line     = comp(Line)
    return e -> begin
        gluniform(prog, :modelmat,   modelmat[e].modelmat)
        gluniform(prog, :thickness,  line[e].thickness)
        gluniform(prog, :MiterLimit, line[e].miter)
    end
end

struct LineRenderer <: AbstractRenderSystem end

Overseer.requested_components(::LineRenderer) =
    (LineVao, LineProgram,
     ModelMat, Material, PointLight, Spatial, Camera3D, IOTarget, LineOptions)

function Overseer.update(::LineRenderer, m::AbstractLedger)
    fbo  = singleton(m, IOTarget)
    prog = singleton(m, LineProgram)
    idc  = m[Selectable]
    bind(fbo)
    draw(fbo)
    glDisable(GL_BLEND)
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

    bind(prog)
    light, ucolor, spat, modelmat, cam =
        m[PointLight], m[UniformColor], m[Spatial], m[ModelMat], m[Camera3D]
    for e in @entities_in(light && ucolor && spat)
        gluniform(prog, light[e], ucolor[e], spat[e])
    end
    for e in @entities_in(spat && cam)
        gluniform(prog, spat[e], cam[e])
    end
    gluniform(prog, :Viewport, Vec2f0(size(m[IOTarget][1])))
    vao, modelmat, line, vis = m[LineVao], m[ModelMat], m[LineOptions], m[Visible]
    for e in @entities_in(vao && modelmat && line)
        evao = vao[e]
        e_line = line[e]
        if vis[e].visible
            gluniform(prog, :modelmat,   modelmat[e].modelmat)
            gluniform(prog, :thickness,  e_line.thickness)
            gluniform(prog, :MiterLimit, e_line.miter)
            if e in idc
                gluniform(prog, :object_id_color, idc[e].color)
            else
                gluniform(prog, :object_id_color, RGBf0(1.0,1.0,1.0))
            end
            GLA.bind(evao)
            GLA.draw(evao)
        end
    end
end
