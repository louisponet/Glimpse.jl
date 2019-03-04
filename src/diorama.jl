import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
Diorama(; kwargs...) = Diorama(:Glimpse, Scene(); kwargs...)
Diorama(scene::Scene; kwargs...) = Diorama(:Glimpse,  scene, nothing, nothing; kwargs...)
Diorama(scene::Scene, screen::Screen; kwargs...) = Diorama(:Glimpse, scene, screen, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene; kwargs...) = Diorama(name, scene, nothing, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene, screen::Screen; kwargs...) =
	Diorama(name, scene, [default_uploader_system(scene),
						  default_render_system(scene),
					      sim_system(scene),
					      camera_system(scene)], screen, [default_renderpass()]; kwargs...)
###########
function free!(dio::Diorama)
    free!(dio.screen)
    free!.(dio.pipeline)
end

function renderloop(dio, framerate = 1/60)
    screen   = dio.screen
    pipeline = dio.pipeline
    scene    = dio.scene
    while !should_close(dio.screen)
        for sys in dio.systems
	        update(sys, dio.scene.entities, dio)
        end
        swapbuffers(dio.screen)

        sleep_pessimistic(framerate - (time()-dio.simdata.time))
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
        dio.loop = @async renderloop(dio)
        # dio.loop = renderloop(dio)
    end
    return dio
end

close(dio::Diorama) = should_close!(dio.screen, true)

function register_callbacks(dio::Diorama)
    dio.pipeline != nothing && register_callbacks.(dio.pipeline, (dio.screen.canvas, ))
end

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end


windowsize(dio::Diorama) = windowsize(dio.screen)

pixelsize(dio::Diorama)  = (windowsize(dio)...,)


function set!(dio::Diorama, pipeline::Vector{RenderPass}, reupload=true)
    dio.pipeline = pipeline
    register_callbacks(pipeline, dio.screen.canvas)
    dio.reupload = true
end

# manipulations

center!(dio::Diorama)    = dio.scene!=nothing && center!(dio.scene)

darken!(dio::Diorama, percentage)  = darken!(dio.scene, percentage)
lighten!(dio::Diorama, percentage) = lighten!(dio.scene, percentage)

set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.scene.campera.rotation_speed = Float32(rotation_speed)
set_background_color!(dio::Diorama, color) = set_background_color!(dio.screen, color)


# SIMDATA
abstract type SimulationSystem <: SystemKind end
struct Timer <: SimulationSystem end 

sim_system(sc::Scene) = System{Timer}(sc, :spatial)

#maybe this should be splitted into a couple of systems
function update(renderer::System{Timer}, entities::Vector{Entity}, dio::Diorama)
	sd = dio.simdata
	nt         = time()
	sd.dtime   = nt - sd.time
	sd.time    = time()
	sd.frames += 1
end




# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.scene.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
