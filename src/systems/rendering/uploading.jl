struct Uploader <: System end

requested_components(::Uploader) =
	(Mesh, BufferColor, DefaultVao, DefaultProgram, LineVao, LineProgram, PeelingProgram, PeelingVao)

shaders(::Type{DefaultProgram}) = default_shaders()
shaders(::Type{PeelingProgram}) = peeling_shaders()
shaders(::Type{InstancedDefaultProgram}) = instanced_default_shaders()
shaders(::Type{InstancedPeelingProgram}) = instanced_peeling_shaders()
shaders(::Type{PeelingCompositingProgram}) = peeling_compositing_shaders()
shaders(::Type{CompositingProgram}) = compositing_shaders()
shaders(::Type{BlendProgram}) = blending_shaders()
shaders(::Type{TextProgram})  = text_shaders()

#TODO cleanup: really not the place to do this
function ECS.prepare(::Uploader, dio::Diorama)
    for prog in components(dio, RenderProgram)
    	if isempty(prog)
        	ProgType = eltype(prog)
    		Entity(dio, ProgType(Program(shaders(ProgType))))
    	end
	end
end

function update(::Uploader, m::Manager)
    mesh, bcolor, ucolor = m[Mesh], m[BufferColor], m[UniformColor]
    default_vao = m[DefaultVao]
    peeling_vao = m[PeelingVao]
    line_vao    = m[LineVao]
    peeling_prog= m[PeelingProgram][1]
    default_prog= m[DefaultProgram][1]
    line_prog   = m[LineProgram][1]
    #Buffer color entities are always not instanced
    for e in entities(mesh, bcolor,exclude=(default_vao, peeling_vao))
        @show e
        e_mesh = mesh[e]
        e_color = bcolor[e].color
        gen_vao = prog -> begin
    		buffers = [generate_buffers(prog, e_mesh.mesh);
    	               generate_buffers(prog, GEOMETRY_DIVISOR, color=e_color)]
            return VertexArray(buffers, faces(e_mesh.mesh) .- GLint(1))
        end

        if any(x -> x.alpha < 1, bcolor[e].color)
		    peeling_vao[e] = PeelingVao(gen_vao(peeling_prog))
	    else
		    default_vao[e] = DefaultVao(gen_vao(default_prog))
	    end
    end

    #Line Entities
    for e in entities(mesh, ucolor, m[Line], exclude=(line_vao,))
        e_mesh = mesh[e]
        line_vao[e] = LineVao(VertexArray(generate_buffers(line_prog, e_mesh.mesh), 11), true)
    end

end

struct InstancedUploader <: System end

function update(::InstancedUploader, m::Manager)
	default_prog = m[InstancedDefaultProgram][1].program	
	peeling_prog = m[InstancedPeelingProgram][1].program	
	default_vao  = m[InstancedDefaultVao]
	peeling_vao  = m[InstancedPeelingVao]
	mesh = m[Mesh]
	if isempty(mesh)
		return
	end
	ucolor = m[UniformColor]
	modelmat = m[ModelMat]
	material = m[Material]

	default_stor = ECS.storage(default_vao)
	peeling_stor = ECS.storage(peeling_vao)
	it   = entities(mesh, ucolor, modelmat, material, exclude=(default_vao, peeling_vao))
	for tmesh in mesh.shared
		default_modelmats = Mat4f0[]
		default_ucolors   = RGBAf0[]
		default_specints  = Float32[]
		default_specpows  = Float32[]

		peeling_modelmats = Mat4f0[]
		peeling_ucolors   = RGBAf0[]
		peeling_specints  = Float32[]
		peeling_specpows  = Float32[]

		default_ids  = Int[]
		peeling_ids  = Int[]
		for e in it
            e_mesh, e_color, e_modelmat, e_material = mesh[e], ucolor[e], modelmat[e],  material[e]
			if e_mesh.mesh === tmesh.mesh
    			if e_color.color.alpha < 1
    				push!(peeling_modelmats, e_modelmat.modelmat)
    				push!(peeling_ucolors, e_color.color)
    				push!(peeling_specints, e_material.specint)
    				push!(peeling_specpows, e_material.specpow)
    				push!(peeling_ids, ECS.id(e))
				else
    				push!(default_modelmats, e_modelmat.modelmat)
    				push!(default_ucolors, e_color.color)
    				push!(default_specints, e_material.specint)
    				push!(default_specpows, e_material.specpow)
    				push!(default_ids, ECS.id(e))
				end
			end
		end
        indices = tmesh.mesh.faces .- GLint(1)
		if !isempty(default_ids)
    		buffers = [generate_buffers(default_prog, tmesh.mesh);
                       generate_buffers(default_prog, GLint(1),
                                        color    = default_ucolors,
                                        modelmat = default_modelmats,
                                        specint  = default_specints,
                                        specpow  = default_specpows)]
			tvao = InstancedDefaultVao(VertexArray(buffers, indices, length(default_ids)), true)
			push!(default_vao.shared, tvao)
			id = length(default_vao.shared)
			for i in default_ids
				default_stor[i, ECS.Reverse()] = id
			end
		end
		if !isempty(peeling_ids)
    		buffers = [generate_buffers(peeling_prog, tmesh.mesh);
                       generate_buffers(peeling_prog, GLint(1),
                                        color    = peeling_ucolors,
                                        modelmat = peeling_modelmats,
                                        specint  = peeling_specints,
                                        specpow  = peeling_specpows)]
			tvao = InstancedPeelingVao(VertexArray(buffers, indices, length(peeling_ids)), true)
			push!(peeling_vao.shared, tvao)
			id = length(peeling_vao.shared)
			for i in peeling_ids
				peeling_stor[i, ECS.Reverse()] = id
			end
		end
	end
end

struct UniformUploader <: System end

requested_components(::UniformUploader) =
    (InstancedDefaultVao, InstancedPeelingVao, ModelMat, Selectable, UniformColor, UpdatedComponents)

# function find_contiguous_bounds(indices)
# 	ranges = UnitRange[]
# 	i = 1
# 	cur_start = indices[1]
# 	while i <= length(indices) - 1
# 		id = indices[i]
# 		id_1 = indices[i + 1]
# 		if id_1 - id != 1
# 			push!(ranges, cur_start:id)
# 			cur_start = id_1
# 		end
# 		i += 1
# 	end
# 	push!(ranges, cur_start:indices[end])
# 	return ranges
# end
function ECS.prepare(::UniformUploader, dio::Diorama)
	if isempty(dio[UpdatedComponents])
		Entity(dio, UpdatedComponents())
	end
end

function update(::UniformUploader, m::Manager)
	uc = m[UpdatedComponents][1]
	mat = m[ModelMat]
	matsize = sizeof(eltype(mat))
	for vao in (m[InstancedDefaultVao], m[InstancedPeelingVao])
    	if ModelMat in uc
        	it1 = entities(vao, mat)
    		for tvao in vao.shared
    			modelmats = Mat4f0[]

    			for e  in it1
                    e_vao, e_modelmat = vao[e], mat[e]
    				if e_vao === tvao
    					push!(modelmats, e_modelmat.modelmat)
    				end
    			end
    			if !isempty(modelmats)
    				binfo = GLA.bufferinfo(tvao.vertexarray, :modelmat)
    				if binfo != nothing
    					GLA.bind(binfo.buffer)
    					s = length(modelmats) * matsize
    					glBufferSubData(binfo.buffer.buffertype, 0, s, pointer(modelmats, 1))
    					GLA.unbind(binfo.buffer)
    				end
    			end
    		end
    	end
        ucolor = m[UniformColor]
    	if UniformColor in uc.components
        	colsize = sizeof(RGBAf0)
        	it2 = entities(vao, m[UniformColor], m[Selectable])
    		for tvao in vao.shared
    			colors = RGBAf0[]
    			for e in it2
        			e_val, e_color, = vao[e], ucolor[e]
    				if e_vao === tvao
    					push!(colors, e_color.color)
    				end
    			end
    			if !isempty(colors)
    				binfo = GLA.bufferinfo(tvao.vertexarray, :color)
    				if binfo != nothing
    					GLA.bind(binfo.buffer)
    					s = length(colors) * colsize
    					glBufferSubData(binfo.buffer.buffertype, 0, s, pointer(colors, 1))
    					GLA.unbind(binfo.buffer)
    				end
    			end
    		end
    	end
	end
end
