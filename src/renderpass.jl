import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype, uniform_names, separate, clear!, gluniform, set_uniform, depth_attachment, color_attachment, id, current_context
#Do we really need the context if it is already in frambuffer and program?

RenderPass{name}(programs::ProgramDict, targets::RenderTargetDict; options...) where name =
    RenderPass{name}(programs, targets, options.data)

RenderPass{name}(shaderdict::Dict{Symbol, Vector{Shader}}, targets::RenderTargetDict; options...) where name =
    RenderPass{name}(Dict([sym => Program(shaders) for (sym, shaders) in shaderdict]), targets; options...)

RenderPass(name::Symbol, args...; options...) =
    RenderPass{name}(args...; options...)

valid_uniforms(rp::RenderPass) = [uniform_names(p) for p in values(rp.programs)]

default_renderpass() = context_renderpass(:default_render, Dict(:main => default_shaders(), :main_instanced => default_instanced_shaders()))
context_renderpass(name::Symbol, shaderdict::Dict{Symbol, Vector{Shader}}) =
    RenderPass(name, shaderdict, RenderTargetDict(:context=>current_context()))

name(::RenderPass{n}) where n = n
main_program(rp::RenderPass) = rp.programs[:main]
main_instanced_program(rp::RenderPass) = rp.programs[:main_instanced]


function free!(rp::RenderPass)
    free!.(values(rp.programs))
    free!.(filter(t-> t != current_context(), collect(values(rp.targets))))
end

function register_callbacks(rp::RenderPass, context=current_context())
    on(wh -> resize_targets(rp, Tuple(wh)),
        callback(context, :framebuffer_size))
end

resize_targets(rp::RenderPass, wh) =
    resize!.(values(rp.targets), (wh,))

function create_transparancy_passes(wh, npasses)
    peel_prog              = Program(peeling_shaders())
    peel_instanced_prog    = Program(peeling_instanced_shaders())
    comp_prog              = Program(compositing_shaders())
    blend_prog             = Program(blending_shaders())

    color_blender, peel1, peel2 =
        [FrameBuffer(wh, (RGBA{Float32}, Depth{Float32}), true) for i= 1:3]
    context_fbo  = current_context()
    targets = RenderTargetDict(:colorblender => color_blender,
                               :context      => context_fbo,
                               :peel1        => peel1,
                               :peel2        => peel2)
    return [RenderPass{:depth_peeling}(ProgramDict(:main => peel_prog, :main_instanced => peel_instanced_prog, :blending => blend_prog, :composite => comp_prog),  targets, num_passes=npasses)]
end

#-------------------- Rendering Functions ------------------------#
rem1(x, y) = (x - 1) % y + 1
# TODO: pass options
# depth peeling with instanced_renderables might give a weird situation?
function (rp::RenderPass{:depth_peeling})(scene::Scene)
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
    canvas_width  = Float32(size(colorblender)[1])
    canvas_height = Float32(size(colorblender)[2])

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
    first_pass(instanced_renderables(rp), peeling_instanced_program)

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
        render(instanced_renderables(rp), peeling_instanced_program)
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
