import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype, uniform_names, separate, clear!, gluniform, set_uniform, depth_attachment, color_attachment, id, current_context
#Do we really need the context if it is already in frambuffer and program?

struct DefaultPass      <: RenderPassKind end
struct DepthPeelingPass <: RenderPassKind end

RenderPass{name}(programs::ProgramDict, targets::RenderTargetDict; options...) where name =
    RenderPass{name}(programs, targets, options.data)

RenderPass{name}(shaderdict::Dict{Symbol, Vector{Shader}}, targets::RenderTargetDict; options...) where name =
    RenderPass{name}(Dict([sym => Program(shaders) for (sym, shaders) in shaderdict]), targets; options...)

RenderPass(name::RenderPassKind, args...; options...) =
    RenderPass{name}(args...; options...)

valid_uniforms(rp::RenderPass) = [uniform_names(p) for p in values(rp.programs)]

default_renderpass() = context_renderpass(DefaultPass, Dict(:main => default_shaders(), :main_instanced => default_instanced_shaders()))
context_renderpass(::Type{Kind}, shaderdict::Dict{Symbol, Vector{Shader}}) where {Kind <: RenderPassKind} =
    RenderPass{Kind}(shaderdict, RenderTargetDict(:context=>current_context()))

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

function create_transparancy_pass(wh, npasses)
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
    return RenderPass{DepthPeelingPass}(ProgramDict(:main => peel_prog, :main_instanced => peel_instanced_prog, :blending => blend_prog, :composite => comp_prog),  targets, num_passes=npasses)
end

#-------------------- Rendering Functions ------------------------#
rem1(x, y) = (x - 1) % y + 1
# TODO: pass options
# depth peeling with instanced_renderables might give a weird situation?
