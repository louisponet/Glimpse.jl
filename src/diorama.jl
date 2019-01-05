import GLAbstraction: free!

#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
mutable struct Diorama
    name     ::Symbol
    scene    ::Scene
    screen   ::Union{Screen, Nothing}
    pipeline ::Union{Vector{Renderpass}, Nothing}
    loop     ::Union{Task, Nothing}
    function Diorama(name, scene, screen, pipeline; interactive=false, kwargs...)
        dio = new(name, scene, screen, pipeline, nothing)
        makecurrentdio(dio)
        expose(dio; kwargs...)
        finalizer(free!, dio)
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

function set!(dio::Diorama, pipeline::Vector{Renderpass})
    dio.pipeline = pipeline
    register_callbacks(pipeline, dio.screen.canvas)
end

"""
Empties the scene that is linked to the diorama, i.e. clearing all the renderables.
"""
Base.empty!(dio::Diorama) = empty!(dio.scene)

set!(dio::Diorama, camera::Camera) = set!(dio.scene, camera)

function free!(dio::Diorama)
    dio.loop     = nothing
    free!(dio.screen)
    free!.(dio.pipeline)
    free!(dio.scene)
end

function renderloop(dio, framerate = 1/60)
    screen   = dio.screen
    pipeline = dio.pipeline
    scene    = dio.scene
    while isopen(dio.screen)
        # clear!(screen.canvas)
        tm = time()
        pollevents(dio.screen)
        if dio.pipeline != nothing
            render(dio.pipeline, dio.scene)
        end
        swapbuffers(dio.screen)
        tm = time() - tm
        sleep_pessimistic(framerate - tm)
    end
    free!(dio)
end

function expose(dio::Diorama;  kwargs...)
    if dio.loop == nothing
        dio.screen = dio.screen == nothing ? Screen(dio.name; kwargs...) : raise(dio.screen)
        register_callbacks(dio)
        resize_event(dio.scene.camera, size(dio.screen.canvas)...)
        dio.loop = @async renderloop(dio)
        # dio.loop = renderloop(dio)
    end
    return dio
end

function register_callbacks(dio::Diorama)
    register_callbacks(dio.scene.camera, dio.screen.canvas)
    dio.pipeline != nothing && register_callbacks.(dio.pipeline, (dio.screen.canvas, ))
end

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end


darken!(dio::Diorama, percentage) = darken!(dio.scene, percentage)

windowsize(dio::Diorama) = windowsize(dio.screen)
pixelsize(dio::Diorama)  = (windowsize(dio)...,)
