import GLAbstraction: Pipeline, RenderPass
import GLAbstraction: free!

#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
mutable struct Diorama
    name     ::Symbol
    scene    ::Scene
    screen   ::Union{Screen, Void}
    pipeline ::Union{Pipeline, Void}
    loop     ::Union{Task, Void}
    function Diorama(name, scene, screen, pipeline; interactive=false, kwargs...)
        if interactive
            screen = screen == nothing ? Screen(name; kwargs...) : screen
            register_camera_callbacks(scene.camera, screen.canvas)
            pipeline = pipeline == nothing ? Pipeline(:default, [RenderPass(:default, defaultshaders())], screen.canvas) : pipeline
            looptask = @async renderloop(dio)
            dio = new(name, scene, screen, pipeline, looptask)
        else
            dio = new(name, scene, screen, pipeline)
        end
        makecurrentdio(dio)
        return dio
    end
end

Diorama(; kwargs...) = Diorama(:Glimpse, Scene(); kwargs...)
Diorama(scene::Scene; kwargs...) = Diorama(:Glimpse, scene, nothing, nothing; kwargs...)
Diorama(scene::Scene, screen::Screen; kwargs...) = Diorama(:Glimpse, scene, screen, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene; kwargs...) = Diorama(name, scene, nothing, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene, screen::Screen; kwargs...) = Diorama(name, scene, screen, nothing; kwargs...)

add!(dio::Diorama, renderable::Renderable) = add!(dio.scene, renderable)
add!(dio::Diorama, light::Light) = add!(dio.scene, light)

"""
Empties the scene that is linked to the diorama, i.e. clearing all the renderables.
"""
Base.empty!(dio::Diorama) = empty!(dio.scene)

set!(dio::Diorama, camera::Camera) = set!(dio.scene, camera)

function free!(dio::Diorama)
    dio.loop     = nothing
    dio.screen   = free!(dio.screen)
    dio.pipeline = free!(dio.pipeline)
    dio.scene    = free!(dio.scene)
end


function renderloop(dio, framerate = 1/60)
    screen = dio.screen
    pipeline = dio.pipeline
    scene = dio.scene
    while isopen(screen)
        tm = time()
        pollevents(screen)
        render(pipeline, scene)
        swapbuffers(screen)
        tm = time() - tm
        sleep_pessimistic(framerate - tm)
    end
    free!(dio)
end

function expose(dio::Diorama)
    if !isdefined(dio, :loop) || dio.loop == nothing
        dio.screen = dio.screen == nothing ? Screen(dio.name; kwargs...) : raise(dio.screen)
        register_camera_callbacks(dio.scene.camera, dio.screen.canvas)
        resize_event(dio.scene.camera, dio.screen.canvas.area)
        dio.pipeline = dio.pipeline == nothing ? Pipeline(:default, [RenderPass(:default, defaultshaders())], dio.screen.canvas) : dio.pipeline
        dio.loop = @async renderloop(dio)
    end
    return dio
end

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end
