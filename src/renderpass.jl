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
mutable struct Renderpass{Name, NT <: NamedTuple}
    # id::Int
    programs              ::ProgramDict
    targets               ::RenderTargetDict
    renderables           ::Vector{GLRenderable}
    instanced_renderables ::Vector{GLRenderable}
    options               ::NT
    function Renderpass{name}(programs::ProgramDict, fbs::RenderTargetDict, renderables::Vector{GLRenderable}, irenderables::Vector{GLRenderable}, options::NT) where {name, NT <: NamedTuple}
        obj = new{name, NT}(programs, fbs, renderables, irenderables, options)
        finalizer(free!, obj)
        return obj
    end
end

Renderpass{name}(programs::ProgramDict, targets::RenderTargetDict; options...) where name =
    Renderpass{name}(programs, targets, GLRenderable[], GLRenderable[], options.data)

Renderpass{name}(shaderdict::Dict{Symbol, Vector{Shader}}, targets::RenderTargetDict; options...) where name =
    Renderpass{name}(Dict([sym => Program(shaders) for (sym, shaders) in shaderdict]), targets; options...)

Renderpass(name::Symbol, args...; options...) =
    Renderpass{name}(args...; options...)

default_renderpass() = context_renderpass(:default, Dict(:main => default_shaders(), :main_instanced => default_instanced_shaders()))
context_renderpass(name::Symbol, shaderdict::Dict{Symbol, Vector{Shader}}) =
    Renderpass(name, shaderdict, RenderTargetDict(:context=>current_context()))

name(::Renderpass{n}) where n = n
main_program(rp::Renderpass) = rp.programs[:main]
main_instanced_program(rp::Renderpass) = rp.programs[:main_instanced]
should_render(rp::Renderpass) = !isempty(rp.renderables) || !isempty(rp.instanced_renderables)

valid_uniforms(rp::Renderpass) = [uniform_names(p) for p in values(rp.programs)]

# render(rp::Renderpass, args...) = rp.render(args...)
function upload(renderables::Vector{<:MeshRenderable}, pass::Renderpass{name}) where name
    #I'm not clear when this would ever happen but fine
    instanced_renderables, normal_renderables = separate(isinstanced, filter(x -> !isuploaded(x, name), filter(x -> haspass(x, name), renderables)))
    if !isempty(instanced_renderables)
        push!(pass.instanced_renderables, InstancedGLRenderable(instanced_renderables, pass))
    end
    for r in instanced_renderables
        r.renderpasses[name] = true
    end
    upload.(normal_renderables, (pass,))
end

function upload(rend::MeshRenderable, pass::Renderpass{name}) where name
    push!(pass.renderables, GLRenderable(rend, pass))
    rend.renderpasses[name] = true
end

isuploaded(rend::MeshRenderable, pass::Renderpass{name}) where name = isuploaded(rend, name)


function free!(rp::Renderpass)
    free!.(values(rp.programs))
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
    peel_instanced_prog    = Program(peeling_instanced_shaders())
    comp_prog    = Program(compositing_shaders())
    blend_prog   = Program(blending_shaders())

    color_blender, peel1, peel2 =
        [FrameBuffer(wh, (RGBA{Float32}, Depth{Float32}), true) for i= 1:3]
    context_fbo  = current_context()
    targets = RenderTargetDict(:colorblender => color_blender, :context => context_fbo,
                               :peel1 => peel1, :peel2 => peel2)
    return [Renderpass{:depth_peeling}(ProgramDict(:main => peel_prog, :main_instanced => peel_instanced_prog, :blending => blend_prog, :composite => comp_prog),  targets, num_passes=npasses)]
end

#-------------------- Rendering Functions ------------------------#
# during rendering
function render(pipe::Vector{Renderpass}, sc::Scene, args...)
    for pass in pipe
        if !should_render(pass)
            continue
        end
        pass(sc, args...)
    end
end

function render(rp::Renderpass, scene::Scene)
    function r(renderables, program)
        if !isempty(renderables)
            bind(program)
            set_scene_uniforms(program, scene)
            render(renderables, program)
        end
    end
    r(rp.renderables, main_program(rp))
    r(rp.instanced_renderables, main_instanced_program(rp))
    unbind(main_program(rp))
end

function render(renderables::Vector{GLRenderable}, program::Program)
    if isempty(renderables)
        return
    end
    for rend in renderables
        bind(rend)
        set_uniforms(program, rend)
        draw(rend)
    end
    unbind(renderables[end])
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
    render(rp, scene)
    # glEnable(GL_CULL_FACE)
    # glCullFace(GL_BACK)
end

function (rp::Renderpass{:simple_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    render(rp, scene)
end

rem1(x, y) = (x - 1) % y + 1
# TODO: pass options
# depth peeling with instanced_renderables might give a weird situation?
function (rp::Renderpass{:depth_peeling})(scene::Scene)
    peeling_program     = main_program(rp)
    peeling_instanced_program   = main_instanced_program(rp)
    blending_program    = rp.programs[:blending]
    colorblender        = rp.targets[:colorblender]
    peeling_targets     = [rp.targets[:peel1], rp.targets[:peel2]]
    context_target      = rp.targets[:context]
    compositing_program = rp.programs[:composite]
    fullscreenvao       = context_target.fullscreenvao
    bind(colorblender)
    draw(colorblender)
    clear!(colorblender, context_target.background)
    # glClearBufferfv(GL_COLOR, 0, [0,0,0,1])
    glEnable(GL_DEPTH_TEST)
    canvas_width  = f32(size(colorblender)[1])
    canvas_height = f32(size(colorblender)[2])

    function first_pass(renderables, program)
        if isempty(renderables)
            return
        end
        bind(program)
        set_uniform(program, :first_pass, true)
        set_scene_uniforms(program, scene)
        set_uniform(program, :canvas_width, canvas_width)
        set_uniform(program, :canvas_height, canvas_height)
        render(renderables, program)
        set_uniform(program, :first_pass, false)
    end

    first_pass(rp.renderables, peeling_program)
    first_pass(rp.instanced_renderables, peeling_instanced_program)

    for layer=1:rp.options.num_passes
        currid = rem1(layer, 2)
        currfbo = peeling_targets[currid]
        previd =  3 - currid
        prevfbo = layer==1 ? colorblender : peeling_targets[previd]
        glEnable(GL_DEPTH_TEST)
        bind(currfbo)
        draw(currfbo)
        # clear!(currfbo)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glDisable(GL_BLEND)
        glEnable(GL_DEPTH_TEST)

        bind(peeling_program)
        set_uniform(peeling_program, :depth_texture, (0, depth_attachment(prevfbo)))
        render(rp.renderables, peeling_program)

        bind(peeling_instanced_program)
        set_uniform(peeling_instanced_program, :depth_texture, (0, depth_attachment(prevfbo)))
        render(rp.instanced_renderables, peeling_instanced_program)

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
