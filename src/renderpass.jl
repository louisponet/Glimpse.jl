import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype
#Do we really need the context if it is already in frambuffer and program?
#TODO: finalizer free!
struct Renderpass{Name}
    # id::Int
    name::Symbol
    program::Program
    target::FrameBuffer
    # render::Function
end
"RednerPass that renders directly to the current context."
function Renderpass(name::Symbol, shaders::Vector{Shader}, target::FrameBuffer)
    prog   = Program(shaders, Tuple{Int, String}[])
    return Renderpass{name}(name, prog, target)
end

function Renderpass(name::Symbol, shaders::Vector{Tuple{String, UInt32}}, target::FrameBuffer)
    pass_shaders = Shader[]
    for (source, typ) in shaders
        push!(pass_shaders, Shader(gensym(), typ, Vector{UInt8}(source)))
    end
    prog   = Program(pass_shaders, Tuple{Int, String}[])
    return Renderpass(name, prog, target)
end

Renderpass(name::Symbol, shaders::Vector{Tuple{Symbol, AbstractString}}, target::FrameBuffer) =
    Renderpass(name, [(Vector{UInt8}(source), shadertype(shname)) for (shname, source) in shaders], target)

context_renderpass(name::Symbol, shaders) = Renderpass(name, shaders, context_framebuffer())

function start(rp::Renderpass)
    bind(rp.target)
    # clear!(rp.target)
    bind(rp.program)
end

function stop(rp::Renderpass)
    unbind(rp.target)
    unbind(rp.program)
end
# render(rp::Renderpass, args...) = rp.render(args...)

function free!(rp::Renderpass)
    free!(rp.program)
    free!(rp.target)
    return
end

resize_framebuffer(rp::Renderpass, w, h) =
    resize!(rp.target, (w, h))
