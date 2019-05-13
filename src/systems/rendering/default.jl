import GLAbstraction: set_uniform

struct DefaultProgram <: ProgramKind end

struct DefaultInstancedProgram <: ProgramKind end

# Using the shared uploader system inside uploading.jl
DefaultUploader(dio::Diorama) = Uploader(DefaultProgram, dio)

DefaultInstancedUploader(dio::Diorama) = InstancedUploader(DefaultInstancedProgram, dio)

struct DefaultRenderer <: AbstractRenderSystem
	data ::SystemData

	function DefaultRenderer(dio::Diorama)
		components = (Vao{DefaultProgram},
				      Vao{DefaultInstancedProgram},
				      Vao{LineProgram},
				      ProgramTag{DefaultProgram},
				      ProgramTag{DefaultInstancedProgram},
				      ProgramTag{LineProgram},
				      Spatial,
				      Material,
				      ModelMat,
				      Color,
				      Shape,
				      PointLight,
				      Line,
				      Camera3D)
	    singletons = (RenderTarget{IOTarget},
     			      RenderProgram{DefaultProgram},
     			      RenderProgram{DefaultInstancedProgram},
     			      RenderProgram{LineProgram})
		return new(SystemData(dio, components, singletons))
	end
end

function update_indices!(sys::DefaultRenderer)
	comp(T)  = component(sys, T)
	spat     = comp(Spatial)
	sys.data.indices = [valid_entities(comp(PointLight), comp(UniformColor), spat),
                        valid_entities(comp(Camera3D), spat),
		                valid_entities(comp(Vao{DefaultProgram}),
		                               spat,
		                               comp(Material),
		                               comp(Shape),
		                               comp(ModelMat),
		                               comp(ProgramTag{DefaultProgram})),
                        valid_entities(comp(Vao{LineProgram}),
                                       comp(Line),
		                               comp(ModelMat),
		                               comp(ProgramTag{LineProgram}))]                       
end


#maybe this should be splitted into a couple of systems
function update(renderer::DefaultRenderer)
	if isempty(indices(renderer))
		return
	end
	allempty = true
	for i in indices(renderer)
		if !isempty(i)
			allempty = false
		end
	end
	if allempty
		return
	end
	comp(T)  = component(renderer, T)
	scomp(T) = shared_component(renderer, T)

	vao      = comp(Vao{DefaultProgram})
	ivao     = scomp(Vao{DefaultInstancedProgram})
	spatial  = comp(Spatial)
	material = comp(Material)
	modelmat = comp(ModelMat)
	shape    = comp(Shape)
	ucolor   = comp(UniformColor)
	prog     = singleton(renderer, RenderProgram{DefaultProgram})


	iprog         = singleton(renderer, RenderProgram{DefaultInstancedProgram})
    ufunc_default = set_entity_uniforms_func(prog, renderer)

	light         = comp(PointLight)

	line_prog     = singleton(renderer, RenderProgram{LineProgram})
	line_vao      = comp(Vao{LineProgram})
    ufunc_lines   = set_entity_uniforms_func(line_prog, renderer)

	iprog         = singleton(renderer, RenderProgram{DefaultInstancedProgram})
    ufunc_default = set_entity_uniforms_func(prog, renderer)

	light         = comp(PointLight)
	camera        = comp(Camera3D)

	fbo           = singleton(renderer, RenderTarget{IOTarget})
	bind(fbo)
	draw(fbo)
	glDisable(GL_BLEND)
	glEnable(GL_DEPTH_TEST)
    glDepthFunc(GL_LEQUAL)

	function set_light_camera_uniforms(prog)
	    for i in indices(renderer)[1]
		    set_uniform(prog, light[i], ucolor[i], spatial[i])
	    end
	    for i in indices(renderer)[2]
		    set_uniform(prog, spatial[i], camera[i])
	    end
    end
	#Render instanced-renderables
	bind(iprog)
    set_light_camera_uniforms(iprog)
    
	for vao in ivao.shared
		if vao.visible
			GLA.bind(vao)
			GLA.draw(vao)
		end
	end

	#Render non-instanced renderables
	bind(prog)
	set_light_camera_uniforms(prog)

	for e in indices(renderer)[3]
		evao   = vao[e]
		if evao.visible
			ufunc_default(e)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end

	#Render lines
	bind(line_prog)
	set_uniform(line_prog, :Viewport, Vec2f0(size(singleton(renderer, RenderTarget{IOTarget}))))
	set_light_camera_uniforms(line_prog)
	for e in indices(renderer)[4]
		evao   = line_vao[e]
		if evao.visible
			ufunc_lines(e)
			GLA.bind(evao)
			GLA.draw(evao)
		end
	end
end
