import GLAbstraction: is_current_context
#the idea of a pipeline together with renderpasses is that one can jus throw in a scene
#and the render functions take care of what renderables get drawn by what passes
struct Pipeline{Name}
    name::Symbol
    passes::Vector{Renderpass}
    context::AbstractContext
end
Pipeline(name::Symbol, rps::Vector{<:Renderpass}, context=current_context()) = Pipeline{name}(name, rps, context)

function render(pipe::Pipeline, sc::Scene, args...)
    start(pipe)
    for pass in pipe.passes
        start(pass)
        setup!.(sc.renderables, (pass,))
        pass(sc, args...)
    end
    stop(pipe.passes[end])
end

function free!(pipe::Pipeline)
    if !is_current_context(pipe.context)
        return pipe
    end
    for pass in pipe.passes
        free!(pass)
    end
    return
end
#overload!
start(pipe::Pipeline) = return

function register_callbacks(pipeline::Pipeline, context=current_context())
    on(wh -> resize_targets(pipeline, wh...),
        callback(context, :framebuffer_size))
end

resize_targets(pipeline::Pipeline, w::Int, h::Int) =
    resize_target.(pipeline.passes, w, h)
