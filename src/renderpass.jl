import GLAbstraction: Program, Shader, FrameBuffer, Float24
import GLAbstraction: context_framebuffer, start, free!, bind, shadertype, uniform_names, separate, clear!
#Do we really need the context if it is already in frambuffer and program?
#TODO: finalizer free!
mutable struct Renderpass{Name, UNT <: NamedTuple}
    # id::Int
    program  ::Program
    target   ::FrameBuffer
    uniforms ::UNT #Any uniforms that depend on the pass, not on the renderable
    # render::Function
    function Renderpass{name}(program::Program, fb::FrameBuffer, uniforms::UNT) where {name, UNT <: NamedTuple}
        obj = new{name, UNT}(program, fb, uniforms)
        valid_names, invalid_names = separate(x -> x ∈ uniform_names(program), keys(uniforms))
        if !isempty(invalid_names)
            @warn "Following names were not inside the program:
                   $(join(invalid_names, "\n"))"
        end
        finalizer(free!, obj)
        return obj
    end
end

Renderpass{name}(shaders::Vector{Shader}, target::FrameBuffer, uniforms::NamedTuple) where name =
    Renderpass{name}(Program(shaders), target, uniforms)

Renderpass{name}(shaders::Vector{Shader}, target::FrameBuffer) where name =
    Renderpass{name}(shaders, target, NamedTuple())

Renderpass(name::Symbol, args...) =
    Renderpass{name}(args...)

context_renderpass(name::Symbol, shaders::Vector{Shader}) =
    Renderpass(name, shaders, context_framebuffer())

name(::Renderpass{n}) where n = n

function start(rp::Renderpass)
    bind(rp.target)
    clear!(rp.target)
    bind(rp.program)
    program = rp.program
    for (k, v) in pairs(rp.uniforms)
        set_uniform(program, k, v)
    end
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

resize_target(rp::Renderpass, w, h) =
    resize!(rp.target, (w, h))
