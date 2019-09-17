import GLAbstraction: set_uniform

struct DefaultProgram <: ProgramKind end

struct InstancedDefaultProgram <: ProgramKind end

ECS.preferred_component_type(::Type{Vao{InstancedDefaultProgram}}) = SharedComponent
ECS.preferred_component_type(::Type{Vao{DefaultProgram}}) = Component

# Using the shared uploader system inside uploading.jl
DefaultUploader() = Uploader{DefaultProgram}()

InstancedDefaultUploader() = Uploader{InstancedDefaultProgram}()

struct DefaultRenderer <: AbstractRenderSystem end

requested_components(::DefaultRenderer) =
	(Vao{DefaultProgram}, RenderProgram{DefaultProgram},
	 ModelMat, Material, PointLight, UniformColor, BufferColor, Spatial, Camera3D, RenderTarget{IOTarget})

function update(::DefaultRenderer, m::Manager)
	fbo  = m[RenderTarget{IOTarget}][1]
	prog = m[RenderProgram{DefaultProgram}][1]
	bind(fbo)
	draw(fbo)
	glDisable(GL_BLEND)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	#Render instanced-renderables
	bind(prog)

    for (l, c, s) in zip(m[PointLight], m[UniformColor], m[Spatial])
	    set_uniform(prog, l, c, s)
    end
    for (s, c) in zip(m[Spatial], m[Camera3D])
	    set_uniform(prog, s, c)
    end

	set_model_material = (e_modelmat, e_material) -> begin
		set_uniform(prog, :specint, e_material.specint)
		set_uniform(prog, :specpow, e_material.specpow)
		set_uniform(prog, :modelmat, e_modelmat.modelmat)
	end

	#Uniform colors
	it = zip(m[Vao{DefaultProgram}], m[ModelMat], m[Material], m[UniformColor])
	for (evao, e_modelmat, e_material, e_color) in it
		if evao.visible
			set_model_material(e_modelmat, e_material)
			set_uniform(prog, :uniform_color, e_color.color)
			set_uniform(prog, :is_uniform, true)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end

	#Colors inside Vao
	it2 = zip(m[Vao{DefaultProgram}], m[ModelMat], m[Material], exclude=(m[UniformColor],))
	for (evao, e_modelmat, e_material) in it2
		if evao.visible
			set_model_material(e_modelmat, e_material)
			set_uniform(prog, :is_uniform, false)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end

struct InstancedDefaultRenderer <: AbstractRenderSystem end

requested_components(::InstancedDefaultRenderer) =
	(Vao{InstancedDefaultProgram}, RenderProgram{InstancedDefaultProgram},
	 PointLight, Spatial, Camera3D, RenderTarget{IOTarget})

#maybe this should be splitted into a couple of systems
function update(::InstancedDefaultRenderer, m::Manager)
	fbo  = m[RenderTarget{IOTarget}][1]
	prog = m[RenderProgram{InstancedDefaultProgram}][1]
	bind(fbo)
	draw(fbo)
	glDisable(GL_BLEND)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	bind(prog)

    for (l, c, s) in zip(m[PointLight], m[UniformColor], m[Spatial])
	    set_uniform(prog, l, c, s)
    end
    for (s, c) in zip(m[Spatial], m[Camera3D])
	    set_uniform(prog, s, c)
    end
	for evao in m[Vao{InstancedDefaultProgram}].shared
		if evao.visible
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end
