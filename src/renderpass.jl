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

default_renderpass() = context_renderpass(:default, Dict(:main => default_shaders(), :main_instanced => default_instanced_shaders()))
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
# function render(pipe::Vector{RenderPass}, sc::Scene, args...)
#     for pass in pipe
#         if !should_render(pass)
#             continue
#         end
#         pass(sc, args...)
#     end
# end

# function render(rp::RenderPass, scene::Scene, vaos_to_render)
#     function r(renderables, program)
#         if !isempty(renderables)
#             bind(program)
#             set_scene_uniforms(program, scene)
#             render(renderables, program)
#         end
#     end
#     r(rp.renderables, main_program(rp))
#     r(rp.instanced_renderables, main_instanced_program(rp))
#     unbind(main_program(rp))
# end

# function render(renderables::Vector{GLRenderable}, program::Program)
#     if isempty(renderables)
#         return
#     end
#     for rend in renderables
#         bind(rend)
#         upload_uniforms(program, rend)
#         draw(rend)
#     end
#     unbind(renderables[end])
# end
#TODO only one light exists
function set_scene_uniforms(program, scene)

    c = component(scene, :camera3d)
    if c != nothing && !isempty(data(c))
	    set_uniform(program, :projview, data(c)[1].projview)
	    set_uniform(program, :campos, data(c)[1].eyepos)
    end

    l = component(scene, :point_light)
    if l != nothing && !isempty(data(l))
        set_uniform(program, Symbol("plight.color"),              data(l)[1].color)
        set_uniform(program, Symbol("plight.position"),           data(l)[1].position)
        set_uniform(program, Symbol("plight.amb_intensity"),      data(l)[1].ambient)
        set_uniform(program, Symbol("plight.specular_intensity"), data(l)[1].specular)
        set_uniform(program, Symbol("plight.diff_intensity"),     data(l)[1].diffuse)
    end

end

function set_uniforms(program::Program, unidict::UniformDict)
    for (key, val) in unidict
        set_uniform(program, key, val)
    end
end
#------------------ DIFFERENT KINDS OF RENDERPASSES ------------------#
#TODO only allows for one light at this point!
function (rp::RenderPass{:default})(scene::Scene, vaos, uniforms)
	program = main_program(rp)
    clear!(rp.targets[:context])
    glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)
    bind(program)
	set_scene_uniforms(program, scene)
	for (vao, unidict) in zip(vaos, uniforms)
		set_uniforms(program, unidict)
		bind(vao)
    	draw(vao)
    	unbind(vao)
	end
    # glEnable(GL_CULL_FACE)
    # glCullFace(GL_BACK)
end

function (rp::RenderPass{:simple_transparency})(scene::Scene)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    render(rp, scene)
end

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
