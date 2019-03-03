import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
Diorama(; kwargs...) = Diorama(:Glimpse, Scene(); kwargs...)
Diorama(scene::Scene; kwargs...) = Diorama(:Glimpse,  scene, nothing, nothing; kwargs...)
Diorama(scene::Scene, screen::Screen; kwargs...) = Diorama(:Glimpse, scene, screen, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene; kwargs...) = Diorama(name, scene, nothing, nothing; kwargs...)
Diorama(name::Symbol, scene::Scene, screen::Screen; kwargs...) =
	Diorama(name, scene, [uploader_system(scene),
						  render_system(scene),
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
function new_system!(dio::Diorama, name::Symbol, components::Vector{Symbol})
	sys = System{name}(component_id.((dio.scene, ), components))
	push!(dio.systems, sys)
end

belongs_to(entity, system) = all(keys(system.components) .∈ (keys(entity.data_ids),))

uploader_system(sc::Scene) = System{:uploader}((geometry = component(sc, :geometry),
                                                render   = component(sc, :render)))

#TODO figure out a better way of vao <-> renderpass maybe really multiple entities with child and parent things 
function update(uploader::System{:uploader}, entities::Vector{Entity}, dio::Diorama)
	if dio.pipeline == nothing
		return
	end
	valid_entities = filter(x -> belongs_to(x, uploader), entities)
	if isempty(valid_entities)
		return
	end
	# println(all(keys(system.components) .∈ (keys(entity.data_ids),)))
	render_data    = data(uploader.components.render)
	geometry_data  = data(uploader.components.geometry)

	for renderpass in dio.pipeline
		instanced_renderables = Dict{AbstractGlimpseMesh, Vector{Entity}}() #meshid => instanced renderables

		for entity in valid_entities
			e_render_data = render_data[data_id(entity, :render)]
			e_geom_data   = geometry_data[data_id(entity, :geometry)]

			if !has_pass(e_render_data, renderpass) || is_uploaded(e_render_data, renderpass)
				continue
			end
			if is_instanced(e_render_data) # creation of vao needs to be deferred until we have all of them
				if !haskey(instanced_renderables, e_geom_data.mesh)
					instanced_renderables[e_geom_data.mesh] = [entity]
				else
					push!(instanced_renderables[e_geom_data.mesh], entity)
				end
			else
			    vao = VertexArray(e_geom_data.mesh, main_program(renderpass))
			    set_uploaded(e_render_data, renderpass, true)
				push!(e_render_data.vertexarrays, vao) #TODO watchout this is not really correct
			end
		end

		#TODO handle instanced_renderables, and uniforms 
		for (mesh, entities) in instanced_renderables 
		end
	end
end

render_system(sc::Scene) = System{:render}((render  =component(sc, :render),
										    spatial =component(sc, :spatial),
										    material=component(sc, :material)))

#maybe this should be splitted into a couple of systems
function update(renderer::System{:render}, entities::Vector{Entity}, dio::Diorama)
	if dio.pipeline == nothing
		return
	end

	valid_entities = filter(x -> belongs_to(x, renderer), entities)
	if isempty(valid_entities)
		return
	end
	render_data   = data(renderer.components.render)
	material_data = data(renderer.components.material)
	spatial_data  = data(renderer.components.spatial)
	for rp in dio.pipeline
		uniform_syms = valid_uniforms(rp)
		vaos_to_render = VertexArray[]
		
		uniforms_to_render = SymAnyDict[]
		for entity in valid_entities
			e_render_data   = render_data[data_id(entity, :render)]
			e_material_data = material_data[data_id(entity, :material)]
			e_spatial_data  = spatial_data[data_id(entity, :spatial)]

			if has_pass(e_render_data, rp) && is_uploaded(e_render_data, rp)
				push!(vaos_to_render, renderpass_vao(e_render_data, rp))
			end

			unidict = UniformDict()
			if :specpow in uniform_syms[1] #TODO handle the multiple programs
				unidict[:specpow] = e_material_data.specpow
				unidict[:specint] = e_material_data.specint
			end
			if :modelmat in uniform_syms[1]
				unidict[:modelmat] = translmat(e_spatial_data.position)
			end
			push!(uniforms_to_render, unidict)
		end
#TODO light entities, camera entities
		rp(dio.scene, vaos_to_render, uniforms_to_render)
	end
end


sim_system(sc::Scene) = System{:simulation}((spatial =component(sc, :spatial),))

#maybe this should be splitted into a couple of systems
function update(renderer::System{:simulation}, entities::Vector{Entity}, dio::Diorama)
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
