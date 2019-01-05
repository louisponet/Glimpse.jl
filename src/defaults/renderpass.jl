import GLAbstraction: gluniform, bind, set_uniform, depth_attachment, color_attachment, id

# Pre rendering
function create_peeling_passes(wh, npasses)
    peel_prog    = Program(peeling_shaders())
    comp_prog    = Program(compositing_shaders())
    framebuffers = [FrameBuffer(wh, (RGBA{N0f8}, Depth{Float32}), true) for i=1:npasses]
    context_fbo  = context_framebuffer()
    depth_ids    = depth_attachment.(framebuffers)
    color_ids    = color_attachment.(framebuffers, 1)
    peel_uniforms= vcat([(first_pass=true, depth_texture = (0, depth_ids[1]))], [(first_pass=false, depth_texture = (0, depth_ids[i-1])) for i=2:npasses])
    comp_uniforms= [(color_texture=(0, color_ids[i]), depth_texture = (1, depth_ids[i])) for i=1:npasses]
    passes       = Renderpass[Renderpass{:peel}(peel_prog, framebuffers[i], peel_uniforms[i]) for i=1:npasses]
    append!(passes, [Renderpass{:composite}(comp_prog, context_fbo, comp_uniforms[i]) for i=npasses:-1:1])
    return passes
end

# during rendering
function render_composite(program)
    fullscreenvao = compositing_vertexarray(program)
    bind(fullscreenvao)
    draw(fullscreenvao)
    unbind(fullscreenvao)
end

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

function set_scene_uniforms(program, scene)
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
end

#TODO only allows for one light at this point!
function (rp::Renderpass{:default})(scene::Scene)
    program = rp.program
    if isempty(scene.renderables)
        return
    end
    set_scene_uniforms(program, scene)
    render.((rp,), scene.renderables)
end

function (rp::Renderpass{:cheap_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    rp_renderables = filter(x -> in(:transparency, x.renderpasses), scene.renderables)
    f = 0.75
    program = rp.program
    set_scene_uniforms(program, scene)
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
    set_scene_uniforms(progran, scene)
    render.((rp,), scene.renderables)
end

function (rp::Renderpass{:peel})(scene::Scene)
    bind(rp.target)
    draw(rp.target)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    program = rp.program
    #default uniforms
    set_scene_uniforms(program, scene)
    #peeling uniforms
    set_uniform(program, :canvas_width, size(rp.target)[1])
    set_uniform(program, :canvas_height, size(rp.target)[2])
    render.((rp,), scene.renderables)
end

function (rp::Renderpass{:composite})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glDepthFunc(GL_ALWAYS) #TODO: This can probably go
    render_composite(rp.program)
end
