import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype, uniform_names, separate, clear!, gluniform, set_uniform, depth_attachment, color_attachment, id
#Do we really need the context if it is already in frambuffer and program?
const RenderTarget = Union{FrameBuffer, Canvas}
#TODO: finalizer free!
mutable struct Renderpass{Name}
    # id::Int
    program  ::Program
    targets  ::Vector{RenderTarget}
    # render::Function
    function Renderpass{name}(program::Program, fbs::Vector{<:RenderTarget}) where name
        obj = new{name}(program, fbs)
        finalizer(free!, obj)
        return obj
    end
end

Renderpass{name}(shaders::Vector{Shader}, targets::Vector{<:RenderTarget}) where name =
    Renderpass{name}(Program(shaders), targets)

Renderpass(name::Symbol, args...) =
    Renderpass{name}(args...)

context_renderpass(name::Symbol, shaders::Vector{Shader}) =
    Renderpass(name, shaders, [context_framebuffer()])

name(::Renderpass{n}) where n = n

# render(rp::Renderpass, args...) = rp.render(args...)

function free!(rp::Renderpass)
    free!(rp.program)
    free!.(filter(t-> t!= current_context(), rp.targets))
end

function register_callbacks(rp::Renderpass, context=current_context())
    on(wh -> resize_targets(rp, Tuple(wh)),
        callback(context, :framebuffer_size))
end
resize_targets(rp::Renderpass, wh) =
    resize!.(rp.targets, (wh,))

function create_peeling_passes(wh, npasses)
    peel_prog    = Program(peeling_shaders())
    comp_prog    = Program(compositing_shaders())
    framebuffers = [FrameBuffer(wh, (RGBA{Float32}, Depth{Float32}), true) for i=1:npasses]
    context_fbo  = current_context()
    passes       = Renderpass[Renderpass{:peel}(peel_prog, framebuffers),
                    Renderpass{:composite}(comp_prog, RenderTarget[framebuffers; context_fbo])]
    return passes
end

#-------------------- Rendering Functions ------------------------#
# during rendering
function render(pipe::Vector{Renderpass}, sc::Scene, args...)
    for pass in pipe
        bind(pass.program)
        setup!.(sc.renderables, (pass,))
        pass(sc, args...)
    end
    unbind(pipe[end].program)
end

function setup!(rend::Renderable{D, F}, pass::Renderpass) where {D, F}
    if !isuploaded(rend)
        rend.vao = VertexArray(rend.verts, pass.program, facelength=F)
    end
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

#------------------ DIFFERENT KINDS OF RENDERPASSES ------------------#
#TODO only allows for one light at this point!
function (rp::Renderpass{:default})(scene::Scene)
    clear!(rp.targets[1])
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)


    glEnable(GL_CULL_FACE)
    glCullFace(GL_BACK)
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
    program=rp.program
    set_scene_uniforms(program, scene)
    set_uniform(program, :canvas_width, size(rp.targets[1])[1])
    set_uniform(program, :canvas_height, size(rp.targets[1])[2])

    glEnable(GL_DEPTH_TEST)
    glDisable(GL_BLEND)
    # glDisable(GL_CULL_FACE)

    for i=1:length(rp.targets)
        target = rp.targets[i]
        first_pass = i == 1
        set_uniform(program, :first_pass, first_pass)
        if !first_pass
            set_uniform(program, :depth_texture, (0, depth_attachment(rp.targets[i-1])))
        end
        bind(target)
        clear!(target)
        render.((rp,), scene.renderables)
    end
end

function (rp::Renderpass{:composite})(scene::Scene)
    target  = rp.targets[end]
    program = rp.program
    bind(target)
    clear!(target)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glDepthFunc(GL_ALWAYS) #TODO: This can probably go


    fullscreenvao = compositing_vertexarray(program)
    bind(fullscreenvao)
    for i=length(rp.targets)-1:-1:1
        tex_target = rp.targets[i]
        set_uniform(program, :color_texture, (0, color_attachment(tex_target, 1)))
        set_uniform(program, :depth_texture, (1, depth_attachment(tex_target)))
        draw(fullscreenvao)
    end
    unbind(fullscreenvao)
end
