import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype, uniform_names, separate, clear!, gluniform, set_uniform, depth_attachment, color_attachment, id
#Do we really need the context if it is already in frambuffer and program?
const RenderTarget = Union{FrameBuffer, Canvas}
const RenderTargetDict = Dict{Symbol, RenderTarget}
const ProgramDict = Dict{Symbol, Program}
#TODO: finalizer free!
# The program is the main program for the heavy rendering and will be used to put the
# correct renderable buffers in the vao in the correct attriblocations
# In the children one can put other renderpasses that hold compositing stuff etc.
mutable struct Renderpass{Name}
    # id::Int
    program  ::Program
    targets  ::RenderTargetDict
    extra_programs ::ProgramDict
    function Renderpass{name}(program::Program, fbs::RenderTargetDict, extra_programs::ProgramDict) where name
        obj = new{name}(program, fbs, extra_programs)
        finalizer(free!, obj)
        return obj
    end
end
Renderpass{name}(shaders::Vector{Shader}, targets::RenderTargetDict, extras::ProgramDict) where name =
    Renderpass{name}(Program(shaders), targets, extras)

Renderpass{name}(shaders::Vector{Shader}, targets::RenderTargetDict) where name =
    Renderpass{name}(Program(shaders), targets, ProgramDict())

Renderpass(name::Symbol, args...) =
    Renderpass{name}(args...)

context_renderpass(name::Symbol, shaders::Vector{Shader}) =
    Renderpass(name, shaders, Dict(:context=>context_framebuffer()))

name(::Renderpass{n}) where n = n

# render(rp::Renderpass, args...) = rp.render(args...)

function free!(rp::Renderpass)
    free!(rp.program)
    free!.(values(rp.extra_programs))
    free!.(filter(t-> t != current_context(), collect(values(rp.targets))))
end

function register_callbacks(rp::Renderpass, context=current_context())
    on(wh -> resize_targets(rp, Tuple(wh)),
        callback(context, :framebuffer_size))
end
resize_targets(rp::Renderpass, wh) =
    resize!.(values(rp.targets), (wh,))

function create_transparancy_passes(wh, npasses)
    peel_prog    = Program(peeling_shaders())
    comp_prog    = Program(compositing_shaders())
    blend_prog   = Program(blending_shaders())

    color_blender, peel1, peel2 =
        [FrameBuffer(wh, (RGBA{Float32}, Depth{Float32}), true) for i= 1:3]
    context_fbo  = current_context()
    targets = RenderTargetDict(:colorblender => color_blender, :context => context_fbo,
                               :peel1 => peel1, :peel2 => peel2)
    return [Renderpass{:depth_peeling}(peel_prog, targets, ProgramDict(:blending => blend_prog, :composite => comp_prog))]
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
    render(renderable, rp.program)
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
    clear!(rp.targets[:context])
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
    glDepthFunc(GL_LESS)
    glDisable(GL_BLEND)

    for i=1:length(rp.targets)
        target = rp.targets[i]
        first_pass = i == 1
        set_uniform(program, :first_pass, first_pass)
        if !first_pass
            set_uniform(program, :depth_texture, (0, depth_attachment(rp.targets[i-1])))
        end
        bind(target)
        # clear!(target)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        render.((rp,), scene.renderables)
    end
end

function (rp::Renderpass{:composite})(scene::Scene)
    target  = rp.targets[end]
    program = rp.program
    bind(target)
    glBindVertexArray(0);
    clear!(target)
    glEnable(GL_BLEND)
    glDisable(GL_DEPTH_TEST)
    glBlendFuncSeparate(GL_DST_ALPHA, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA)
    glBlendEquation(GL_FUNC_ADD)
    # glDepthFunc(GL_ALWAYS) #TODO: This can probably go

    # glEnable(GL_CULL_FACE)
    # glCullFace(GL_BACK)
    fullscreenvao = compositing_vertexarray(program)
    bind(fullscreenvao)
    for i=1:length(rp.targets)-1
        tex_target = rp.targets[i]
        set_uniform(program, :color_texture, (0, color_attachment(tex_target, 1)))
        set_uniform(program, :depth_texture, (1, depth_attachment(tex_target)))
        draw(fullscreenvao)
    end
    # for i=1
    #     tex_target = rp.targets[i]
    #     set_uniform(program, :color_texture, (0, color_attachment(tex_target, 1)))
    #     set_uniform(program, :depth_texture, (1, depth_attachment(tex_target)))
    #     draw(fullscreenvao)
    # end
    unbind(fullscreenvao)
end

rem1(x, y) = (x - 1) % y + 1
clear!(fbo::FrameBuffer, color::RGBA) = clear!(fbo, (color.r, color.g, color.b, color.alpha))
# TODO: pass options
function (rp::Renderpass{:depth_peeling})(scene::Scene)
    peeling_program     = rp.program
    blending_program    = rp.extra_programs[:blending]
    colorblender        = rp.targets[:colorblender]
    peeling_targets     = [rp.targets[:peel1], rp.targets[:peel2]]
    context_target      = rp.targets[:context]
    compositing_program = rp.extra_programs[:composite]
    fullscreenvao       = context_target.fullscreenvao
    bind(colorblender)
    draw(colorblender)
    clear!(colorblender, context_target.background)
    # glClearBufferfv(GL_COLOR, 0, [0,0,0,1])
    glEnable(GL_DEPTH_TEST)
    canvas_width  = f32(size(colorblender)[1])
    canvas_height = f32(size(colorblender)[2])
    set_uniform(peeling_program, :first_pass, true)
    set_scene_uniforms(peeling_program, scene)
    set_uniform(peeling_program, :canvas_width, canvas_width)
    set_uniform(peeling_program, :canvas_height, canvas_height)

    render.((rp,), scene.renderables)

    set_uniform(peeling_program, :first_pass, false)

    num_passes = 3
    for layer=1:num_passes
        currid = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd =  3 - currid
        prevfbo = layer==1 ? colorblender : peeling_targets[previd]
        glEnable(GL_DEPTH_TEST)
        bind(currfbo)
        draw(currfbo)
        # clear!(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        bind(peeling_program)
        glDisable(GL_BLEND)
        glEnable(GL_DEPTH_TEST)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))

        render.((rp,), scene.renderables)

        bind(colorblender)
        draw(colorblender)

        glDisable(GL_DEPTH_TEST)
        glEnable(GL_BLEND)
        glBlendEquation(GL_FUNC_ADD)
        glBlendFuncSeparate(GL_DST_ALPHA, GL_ONE, GL_ZERO, GL_ONE_MINUS_SRC_ALPHA)

        bind(blending_program)
        set_uniform(blending_program, :color_texture, (0, color_attachment(currfbo, 1)))

        bind(fullscreenvao)
        draw(fullscreenvao)

        glDisable(GL_BLEND)
    end
    bind(compositing_program)
    bind(rp.targets[:context])
    clear!(rp.targets[:context])
    glDrawBuffer(GL_BACK)
    glDisable(GL_DEPTH_TEST)

    set_uniform(compositing_program, :color_texture, (0, color_attachment(colorblender, 1)))
    # set_uniform(compositing_program, :color_texture, (0, color_attachment(peeling_targets[1], 1)))
    bind(fullscreenvao)
    draw(fullscreenvao)
    glFlush()

end
