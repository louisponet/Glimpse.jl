import GLAbstraction: Program, Shader, FrameBuffer
import GLAbstraction: contextfbo, start, free!, bind, shadertype
#Do we really need the context if it is already in frambuffer and program?
#TODO: finalizer free!
struct RenderPass{Name}
    # id::Int
    name::Symbol
    program::Program
    target::FrameBuffer
    # render::Function
end
"RednerPass that renders directly to the current context."
function RenderPass(name::Symbol, shaders::Vector{Shader}, target::FrameBuffer)
    prog   = Program(shaders, Tuple{Int, String}[])
    return RenderPass{name}(name, prog, target)
end

function RenderPass(name::Symbol, shaders::Vector{Tuple{String, UInt32}}, target::FrameBuffer)
    pass_shaders = Shader[]
    for (source, typ) in shaders
        push!(pass_shaders, Shader(gensym(), typ, Vector{UInt8}(source)))
    end
    prog   = Program(pass_shaders, Tuple{Int, String}[])
    return RenderPass(name, prog, target)
end

RenderPass(name::Symbol, shaders::Vector{Tuple{Symbol, AbstractString}}, target::FrameBuffer) =
    RenderPass(name, [(Vector{UInt8}(source), shadertype(shname)) for (shname, source) in shaders], target)

context_renderpass(name::Symbol, shaders, size) = RenderPass(name, shaders, defaultframebuffer(size))

function start(rp::RenderPass)
    bind(rp.target)
    # clear!(rp.target)
    bind(rp.program)
end

function stop(rp::RenderPass)
    unbind(rp.target)
    unbind(rp.program)
end
# render(rp::RenderPass, args...) = rp.render(args...)


function free!(rp::RenderPass)
    free!(rp.program)
    free!(rp.target)
    return
end
