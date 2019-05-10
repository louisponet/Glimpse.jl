import GLAbstraction: set_uniform

struct UniformCalculator <: System
	data::SystemData

	UniformCalculator(dio::Diorama) = new(SystemData(dio, (Spatial, Shape, ModelMat, Dynamic, Camera3D), (UpdatedComponents,)))
end

function update_indices!(sys::UniformCalculator)
	val_es(x...)  = valid_entities(sys, x...)
	dynamic_entities = val_es(Dynamic)
	already_filled   = val_es(ModelMat)
	es               = val_es(Spatial, Shape)
	es1              = setdiff(setdiff(val_es(Spatial), val_es(Shape)), val_es(Camera3D))
	sys.data.indices = [setdiff(es, already_filled),
                        es ∩ dynamic_entities,
                        setdiff(es1, already_filled),
                        es1 ∩ dynamic_entities]
end

function update(sys::UniformCalculator)
	comp(T) = component(sys, T) 
	spatial  = comp(Spatial)
	shape    = comp(Shape)
	dyn      = comp(Dynamic)
	modelmat = comp(ModelMat)
	for e in indices(sys)[1]
		modelmat[e] = ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale)))
	end
	for e in indices(sys)[3]
		modelmat[e] = ModelMat(translmat(spatial[e].position))
	end
	# Updating uniforms if it's updated
	uc       = singleton(sys, UpdatedComponents)
	if Spatial in uc || Shape in uc
		push!(singleton(sys, UpdatedComponents), ModelMat)
		Threads.@threads for e in indices(sys)[2]
			overwrite!(modelmat, ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale))), e)
		end
		Threads.@threads for e in indices(sys)[4]
			overwrite!(modelmat, ModelMat(translmat(spatial[e].position)), e)
		end
	end
end

function set_entity_uniforms_func(render_program::RenderProgram{<:Union{DefaultProgram, PeelingProgram, LineProgram}}, system::System)
    prog = render_program.program
    material = component(system, Material)
    modelmat = component(system, ModelMat)
    ucolor   = component(system, UniformColor)
	return e -> begin
		set_uniform(prog, :specint, material[e].specint)
		set_uniform(prog, :specpow, material[e].specpow)
		set_uniform(prog, :modelmat, modelmat[e].modelmat)
		if has_entity(ucolor, e)
			set_uniform(prog, :uniform_color, ucolor[e].color)
			set_uniform(prog, :is_uniform, true)
		else
			set_uniform(prog, :is_uniform, false)
			set_uniform(prog, :specpow, material[e].specpow)
		end
	end
end

function set_uniform(program::GLA.Program, spatial, camera::Camera3D)
    set_uniform(program, :projview, camera.projview)
    set_uniform(program, :campos,   spatial.position)
end

function set_uniform(program::GLA.Program, pointlight::PointLight, color::UniformColor, spatial::Spatial)
    set_uniform(program, Symbol("plight.color"),              RGB(color.color))
    set_uniform(program, Symbol("plight.position"),           spatial.position)
    set_uniform(program, Symbol("plight.amb_intensity"),      pointlight.ambient)
    set_uniform(program, Symbol("plight.specular_intensity"), pointlight.specular)
    set_uniform(program, Symbol("plight.diff_intensity"),     pointlight.diffuse)
end
