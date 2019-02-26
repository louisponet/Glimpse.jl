import GLAbstraction: free!

#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
Diorama(; kwargs...) = Diorama(:Glimpse, Scene(); kwargs...)
Diorama(scene::Scene; kwargs...) = Diorama(:Glimpse, scene, nothing, nothing; kwargs...)
Diorama(scene::Scene, screen::Screen; kwargs...) = Diorama(:Glimpse, scene, screen, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene; kwargs...) = Diorama(name, scene, nothing, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene, screen::Screen; kwargs...) = Diorama(name, scene, screen, nothing; kwargs...)

function free!(dio::Diorama)
    free!(dio.screen)
    free!.(dio.pipeline)
end

function renderloop(dio, framerate = 1/60)
    screen   = dio.screen
    pipeline = dio.pipeline
    scene    = dio.scene
    while !should_close(dio.screen)
        if dio.reupload
            reupload(dio)
            dio.reupload = false
        end
        tm = time()
        pollevents(dio.screen)
        if dio.pipeline != nothing
            render(dio.pipeline, dio.scene)
        end
        swapbuffers(dio.screen)

        tm = time() - tm
        sleep_pessimistic(framerate - tm)
    end
    close(dio.screen)
	dio.loop = nothing
    # free!(dio)
end

function reload(dio::Diorama)
	close(dio)
	while isopen(dio.screen) && dio.loop != nothing
		sleep(0.01)
	end
	dio.reupload = true
    expose(dio)
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

close(dio::Diorama) = should_close!(dio.screen, true)


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

renderables(dio::Diorama) = isempty(dio.scene.renderables) ? MeshRenderable[] : renderables(dio.scene)


windowsize(dio::Diorama) = windowsize(dio.screen)

pixelsize(dio::Diorama)  = (windowsize(dio)...,)

center!(dio::Diorama)    = dio.scene!=nothing && center!(dio.scene)

function reupload(dio::Diorama)
	renderables = filter(x -> x.should_upload, dio.scene.renderables)
	for rp in dio.pipeline
		upload(filter(x->haspass(x, rp), renderables), rp)
	end
end
present(dio::Diorama, object, args...; kwargs...) = add!(dio, MeshRenderable(object, args...; kwargs...))

add!(dio::Diorama, renderable::MeshRenderable; reupload=true) =
    (add!(dio.scene, renderable); dio.reupload = reupload)

add!(dio::Diorama, light::Light) = add!(dio.scene, light)

function set!(dio::Diorama, pipeline::Vector{RenderPass}, reupload=true)
    dio.pipeline = pipeline
    register_callbacks(pipeline, dio.screen.canvas)
    dio.reupload = true
end


set!(dio::Diorama, camera::Camera) = set!(dio.scene, camera)


# manipulations
"""
Empties the scene that is linked to the diorama, i.e. clearing all the renderables.
"""
function clear_renderables!(dio::Diorama)
    empty!(dio.scene)
    for rp in dio.pipeline
        empty!(rp.renderables)
    end
end

darken!(dio::Diorama, percentage)  = darken!(dio.scene, percentage)
lighten!(dio::Diorama, percentage) = lighten!(dio.scene, percentage)

set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.scene.campera.rotation_speed = Float32(rotation_speed)
set_background_color!(dio::Diorama, color) = set_background_color!(dio.screen, color)



