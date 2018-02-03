import GLAbstraction: Pipeline, RenderPass
import GLAbstraction: free!
const vista_loop = RefValue{Task}()
#todo, make it so args and kwargs get all passed around to pipelines and screens etc
mutable struct Vista
    name     ::Symbol
    scene    ::Scene
    screen   ::Union{Screen, Void}
    pipeline ::Union{Pipeline, Void}
    loop     ::Union{Task, Void}
    function Vista(name, scene, screen, pipeline; interactive=false)
        if interactive
            screen = screen == nothing ? Screen(name) : screen
            register_camera_callbacks(scene.camera, screen.canvas)
            pipeline = pipeline == nothing ? Pipeline(:default, [RenderPass(:default, default_shaders())], screen.canvas) : pipeline
            looptask = @async renderloop(vista)
            vista = new(name, scene, screen, pipeline, looptask)
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
    vista.screen   = free!(screen)
    vista.pipeline = free!(pipeline)
    vista.scene    = free!(scene)
    vista.loop     = nothing
end

function raise(vista::Vista)
    if !isdefined(vista, :loop) || vista.loop == nothing
        vista.screen = vista.screen == nothing ? Screen(vista.name) : raise(vista.screen)
        register_camera_callbacks(vista.scene.camera, vista.screen.canvas)
        vista.pipeline = vista.pipeline == nothing ? Pipeline(vista.name, [RenderPass(:default, default_shaders())], vista.screen.canvas) : vista.pipeline
        vista.loop = @async renderloop(vista)
    end
    return vista
end
