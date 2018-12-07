import GLAbstraction: is_current_context
#the idea of a pipeline together with renderpasses is that one can jus throw in a scene
#and the render functions take care of what renderables get drawn by what passes
struct PipeLine{Name}
    name::Symbol
    passes::Vector{RenderPass}
    context::AbstractContext
end
PipeLine(name::Symbol, rps::Vector{<:RenderPass}, context=current_context()) = PipeLine{name}(name, rps, context)

function render(pipe::PipeLine, sc::Scene, args...)
    start(pipe)
    for pass in pipe.passes
        start(pass)
        setup!.(sc.renderables, (pass,))
        pass(sc, args...)
    end
    stop(pipe.passes[end])
end

function free!(pipe::PipeLine)
    if !is_current_context(pipe.context)
        return pipe
    end
    for pass in pipe.passes
        free!(pass)
    end
    return
end
#overload!
start(pipe::PipeLine) = return
