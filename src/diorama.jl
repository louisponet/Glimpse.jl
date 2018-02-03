import GLAbstraction: Pipeline, RenderPass
import GLAbstraction: free!

#todo, make it so args and kwargs get all passed around to pipelines and screens etc
mutable struct Diorama
    name     ::Symbol
    scene    ::Scene
    screen   ::Union{Screen, Void}
    pipeline ::Union{Pipeline, Void}
    loop     ::Union{Task, Void}
    function Diorama(name, scene, screen, pipeline; interactive=false)
        if interactive
            screen = screen == nothing ? Screen(name) : screen
            register_camera_callbacks(scene.camera, screen.canvas)
            pipeline = pipeline == nothing ? Pipeline(:default, [RenderPass(:default, default_shaders())], screen.canvas) : pipeline
            looptask = @async renderloop(diorama)
            diorama = new(name, scene, screen, pipeline, looptask)
        else
            diorama = new(name, scene, screen, pipeline)
        end
        return diorama
    end
end

Diorama(; kwargs...) = Diorama(:Glimpse, Scene(); kwargs...)
Diorama(scene::Scene; kwargs...) = Diorama(:Glimpse, scene, nothing, nothing; kwargs...)
Diorama(scene::Scene, screen::Screen; kwargs...) = Diorama(:Glimpse, scene, screen, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene; kwargs...) = Diorama(name, scene, nothing, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene, screen::Screen; kwargs...) = Diorama(name, scene, screen, nothing; kwargs...)

add!(diorama::Diorama, renderable::Renderable) = add!(diorama.scene, renderable)


set!(diorama::Diorama, camera::Camera) = set!(diorama.scene, camera)

function renderloop(diorama, framerate = 1/60)
    screen = diorama.screen
    pipeline = diorama.pipeline
    scene = diorama.scene
    while isopen(screen)
        tm = time()
        pollevents(screen)
        render(pipeline, scene)
        swapbuffers(screen)
        tm = time() - tm
        sleep_pessimistic(framerate - tm)
    end
    diorama.screen   = free!(screen)
    diorama.pipeline = free!(pipeline)
    diorama.scene    = free!(scene)
    diorama.loop     = nothing
end

function build(diorama::Diorama)
    if !isdefined(diorama, :loop) || diorama.loop == nothing
        diorama.screen = diorama.screen == nothing ? Screen(diorama.name) : raise(diorama.screen)
        register_camera_callbacks(diorama.scene.camera, diorama.screen.canvas)
        diorama.pipeline = diorama.pipeline == nothing ? Pipeline(diorama.name, [RenderPass(:default, default_shaders())], diorama.screen.canvas) : diorama.pipeline
        diorama.loop = @async renderloop(diorama)
    end
    return diorama
end
