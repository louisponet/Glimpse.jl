import GLAbstraction: set_uniform

struct UniformCalculator <: System end

requested_components(::UniformCalculator) = (Spatial, Shape, ModelMat, Dynamic, Camera3D, UpdatedComponents)

function update(::UniformCalculator, m::AbstractManager)
	uc        = m[UpdatedComponents][1]
	m_updated = false
	modelmat  = m[ModelMat]
	dyn       = m[Dynamic]
	camera    = m[Camera3D]
	spatial   = m[Spatial]
	shape     = m[Shape]
	for e in entities(spatial)
		if !in(e, modelmat) || in(e, dyn) || in(e, camera) || in(Spatial, uc)
			m_updated = true
			if in(e, shape)
				modelmat[e] = ModelMat(translmat(spatial[e].position) * scalemat(Vec3f0(shape[e].scale)))
			else
				modelmat[e] = ModelMat(translmat(spatial[e].position))
			end
		end
	end
	if m_updated
		push!(uc, ModelMat)
	end
end

function set_entity_uniforms_func(render_program::Union{DefaultProgram, PeelingProgram, LineProgram}, system::System)
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
