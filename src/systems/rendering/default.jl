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

    light, ucolor, spat, cam, modelmat, material, vao =
        m[PointLight], m[UniformColor], m[Spatial], m[Camera3D], m[ModelMat], m[Material], m[Vao{DefaultProgram}]

    for e in entities(light, ucolor, spat)
	    set_uniform(prog, light[e], ucolor[e], spat[e])
    end
    cam = 
    for e in entities(spat, cam)
	    set_uniform(prog, spat[e], cam[e])
    end

	set_model_material = (e_modelmat, e_material) -> begin
		set_uniform(prog, :specint, e_material.specint)
		set_uniform(prog, :specpow, e_material.specpow)
		set_uniform(prog, :modelmat, e_modelmat.modelmat)
	end

	#Uniform colors
	for e in entities(vao, modelmat, material, ucolor)
    	evao = vao[e]
		if evao.visible
			set_model_material(modelmat[e], material[e])
			set_uniform(prog, :uniform_color, ucolor[e].color)
			set_uniform(prog, :is_uniform, true)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end

	#Colors inside Vao
	for e in entities(vao, modelmat, material, exclude=(ucolor,))
    	evao = vao[e]
		if evao.visible
			set_model_material(modelmat[e], material[e])
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

    light, ucolor, spat, cam,  material, vao =
        m[PointLight], m[UniformColor], m[Spatial], m[Camera3D], m[Material], m[Vao{InstancedDefaultProgram}]

    for e in entities(light, ucolor, spat)
	    set_uniform(prog, light[e], ucolor[e], spat[e])
    end
    for e in entities(spat, cam)
	    set_uniform(prog, spat[e], cam[e])
    end
	for evao in vao.shared
		@time if evao.visible
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end
