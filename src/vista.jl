import GLAbstraction: Pipeline, RenderPass

const vista_loop = RefValue{Task}()
#todo, make it so args and kwargs get all passed around to pipelines and screens etc
mutable struct Vista
    name     ::Symbol
    scene    ::Scene 
    screen   ::Union{Screen, Void}
    pipeline ::Union{Pipeline, Void}
    function Vista(name, scene, screen, pipeline; interactive=false)
        if interactive
            screen = screen == nothing ? Screen(name) : screen
            pipeline = pipeline == nothing ? Pipeline(name, [RenderPass(:default, default_shaders())], screen.canvas) : pipeline
            vista = new(name, scene, screen, pipeline)
            vista_loop[] = @async renderloop(vista)
        else
            vista = new(name, scene, screen, pipeline)
        end
        return vista
    end
end

Vista(; kwargs...) = Vista(:GLider, Scene(); kwargs...)
Vista(scene::Scene; kwargs...) = Vista(:GLider, scene, nothing, nothing; kwargs...)
Vista(scene::Scene, screen::Screen; kwargs...) = Vista(:GLider, scene, screen, nothing; kwargs...)
Vista(name::Symbol, scene::Scene; kwargs...) = Vista(name, scene, nothing, nothing; kwargs...)
Vista(name::Symbol, scene::Scene, screen::Screen; kwargs...) = Vista(name, scene, screen, nothing; kwargs...)

add!(vista::Vista, renderable::Renderable) = add!(vista.scene, renderable)
set!(vista::Vista, camera::Camera) = set!(vista.scene, camera)

function renderloop(vista, framerate = 1/60)
    screen = vista.screen
    pipeline = vista.pipeline
    scene = vista.scene
    while isopen(screen)
        tm = time()
        pollevents(screen)
        render(pipeline, scene) 
        swapbuffers(screen)
        tm = time() - tm
        sleep_pessimistic(framerate - tm)
    end
    destroy!(screen)
    free!(pipeline)
    free!(scene)
end


