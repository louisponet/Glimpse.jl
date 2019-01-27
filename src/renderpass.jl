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
    programs    ::ProgramDict
    targets     ::RenderTargetDict
    renderables ::Vector{GLRenderable}
    function Renderpass{name}(programs::ProgramDict, fbs::RenderTargetDict, renderables::Vector{GLRenderable}) where name
        obj = new{name}(programs, fbs, renderables)
        finalizer(free!, obj)
        return obj
    end
end

Renderpass{name}(programs::ProgramDict, targets::RenderTargetDict) where name =
    Renderpass{name}(programs, targets, GLRenderable[])

Renderpass{name}(shaderdict::Dict{Symbol, Vector{Shader}}, targets::RenderTargetDict, renderables::Vector{GLRenderable}) where name =
    Renderpass{name}(Dict([sym => Program(shaders) for (sym, shaders) in shaderdict]), targets, renderables)

Renderpass{name}(shaderdict::Dict{Symbol, Vector{Shader}}, targets::RenderTargetDict) where name =
    Renderpass{name}(shaderdict, targets, GLRenderable[])

Renderpass(name::Symbol, args...) =
    Renderpass{name}(args...)

context_renderpass(name::Symbol, shaders::Vector{Shader}) =
    Renderpass(name, shaders, Dict(:context=>context_framebuffer()))

name(::Renderpass{n}) where n = n
main_program(rp::Renderpass) = rp.programs[:main]
valid_uniforms(rp::Renderpass) = [uniform_names(p) for p in values(rp.programs)]

# render(rp::Renderpass, args...) = rp.render(args...)

function upload(rend::MeshRenderable, pass::Renderpass{name}) where name
    push!(pass.renderables, GLRenderable(rend, pass))
    rend.renderpasses[name] = true
end

isuploaded(rend::MeshRenderable, pass::Renderpass{name}) where name =
    haskey(rend.renderpasses, name) && rend.renderpasses[name]


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
    comp_prog    = Program(compositing_shaders())
    blend_prog   = Program(blending_shaders())

    color_blender, peel1, peel2 =
        [FrameBuffer(wh, (RGBA{Float32}, Depth{Float32}), true) for i= 1:3]
    context_fbo  = current_context()
    targets = RenderTargetDict(:colorblender => color_blender, :context => context_fbo,
                               :peel1 => peel1, :peel2 => peel2)
    return [Renderpass{:depth_peeling}(ProgramDict(:main => peel_prog, :blending => blend_prog, :composite => comp_prog),  targets)]
end

#-------------------- Rendering Functions ------------------------#
# during rendering
function render(pipe::Vector{Renderpass}, sc::Scene, args...)
    for pass in pipe
        if isempty(pass.renderables)
            continue
        end
        bind(main_program(pass))
        pass(sc, args...)
    end
    unbind(main_program(pipe[end]))
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


    # glEnable(GL_CULL_FACE)
    # glCullFace(GL_BACK)
    program = main_program(rp)
    set_scene_uniforms(program, scene)
    render(rp.renderables, program)
end

function (rp::Renderpass{:simple_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    program = main_program(rp)
    set_scene_uniforms(progran, scene)
    render(rp.renderables, program)
end

rem1(x, y) = (x - 1) % y + 1
# TODO: pass options
function (rp::Renderpass{:depth_peeling})(scene::Scene)
    peeling_program     = main_program(rp)
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
    set_uniform(peeling_program, :first_pass, true)
    set_scene_uniforms(peeling_program, scene)
    set_uniform(peeling_program, :canvas_width, canvas_width)
    set_uniform(peeling_program, :canvas_height, canvas_height)

    render(rp.renderables, peeling_program)

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

        render(rp.renderables, peeling_program)

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
