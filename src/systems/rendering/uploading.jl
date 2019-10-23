struct Uploader <: System end

ECS.requested_components(::Uploader) =
	(Mesh, BufferColor, DefaultVao, DefaultProgram, LineVao, LineProgram, PeelingProgram, PeelingVao, LineGeometry)

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
    		dio[Entity(1)] = ProgType(Program(shaders(ProgType)))
    	end
	end
end

function ECS.update(::Uploader, m::AbstractManager)
    mesh, bcolor, ucolor = m[Mesh], m[BufferColor], m[UniformColor]
    default_vao = m[DefaultVao]
    peeling_vao = m[PeelingVao]
    line_vao    = m[LineVao]
    peeling_prog= m[PeelingProgram][1]
    default_prog= m[DefaultProgram][1]
    line_prog   = m[LineProgram][1]

    #Buffer color entities are always not instanced
    for e in @entities_in(mesh && bcolor && !default_vao && !peeling_vao)
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
    line_geom = m[LineGeometry]

    #Line Entities
    for e in @entities_in(line_geom && ucolor)
        e_geom = line_geom[e]
        vert_loc = attribute_location(line_prog.program, :vertices)
        if !(e in line_vao)
            line_vao[e] = LineVao(VertexArray([BufferAttachmentInfo(:vertices, vert_loc, Buffer(e_geom.points), GEOMETRY_DIVISOR)], 11), true)
        else
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :vertices).buffer, e_geom.points)
        end
    end
    empty!(line_geom)
end

struct InstancedUploader <: System end

function ECS.update(::InstancedUploader, m::AbstractManager)
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

	it   = @entities_in(mesh && ucolor && modelmat && material && !default_vao && !peeling_vao)
	for tmesh in mesh.shared
		default_modelmats = Mat4f0[]
		default_ucolors   = RGBAf0[]
		default_specints  = Float32[]
		default_specpows  = Float32[]

		peeling_modelmats = Mat4f0[]
		peeling_ucolors   = RGBAf0[]
		peeling_specints  = Float32[]
		peeling_specpows  = Float32[]

		default_ids  = Entity[]
		peeling_ids  = Entity[]
		for e in it
            e_mesh, e_color, e_modelmat, e_material = mesh[e], ucolor[e], modelmat[e],  material[e]
			if e_mesh.mesh === tmesh.mesh
    			if e_color.color.alpha < 1
    				push!(peeling_modelmats, e_modelmat.modelmat)
    				push!(peeling_ucolors, e_color.color)
    				push!(peeling_specints, e_material.specint)
    				push!(peeling_specpows, e_material.specpow)
    				push!(peeling_ids, e)
				else
    				push!(default_modelmats, e_modelmat.modelmat)
    				push!(default_ucolors, e_color.color)
    				push!(default_specints, e_material.specint)
    				push!(default_specpows, e_material.specpow)
    				push!(default_ids, e)
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
			for e in default_ids
    			default_vao[e] = tvao
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
			for e in peeling_ids
    			peeling_vao[e] = tvao
			end
		end
	end
end

struct UniformUploader <: System end

ECS.requested_components(::UniformUploader) =
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

function ECS.update(::UniformUploader, m::AbstractManager)
	uc = m[UpdatedComponents][1]
	mat = m[ModelMat]
	matsize = sizeof(eltype(mat))
	for vao in (m[InstancedDefaultVao], m[InstancedPeelingVao])
    	if ModelMat in uc
        	it1 = @entities_in(vao && mat)
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
    					glBufferData(binfo.buffer.buffertype, s, pointer(modelmats, 1), binfo.buffer.usage)
    					GLA.unbind(binfo.buffer)
    				end
    			end
    		end
    	end
        ucolor = m[UniformColor]
    	if UniformColor in uc.components
        	colsize = sizeof(RGBAf0)
        	it2 = @entities_in(vao && m[UniformColor] && m[Selectable])
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
    					glBufferData(binfo.buffer.buffertype, s, pointer(colors, 1), binfo.buffer.usage)
    					GLA.unbind(binfo.buffer)
    				end
    			end
    		end
    	end
	end
end
