struct Uploader <: System end

Overseer.requested_components(::Uploader) =
	(Mesh, BufferColor, DefaultVao, DefaultProgram, LineVao, LineProgram, PeelingProgram, PeelingVao, LineGeometry, Alpha)

shaders(::Type{DefaultProgram}) = default_shaders()
shaders(::Type{PeelingProgram}) = peeling_shaders()
shaders(::Type{InstancedDefaultProgram}) = instanced_default_shaders()
shaders(::Type{InstancedPeelingProgram}) = instanced_peeling_shaders()
shaders(::Type{PeelingCompositingProgram}) = peeling_compositing_shaders()
shaders(::Type{CompositingProgram}) = compositing_shaders()
shaders(::Type{BlendProgram}) = blending_shaders()
shaders(::Type{TextProgram})  = text_shaders()

#TODO cleanup: really not the place to do this
function Overseer.prepare(::Uploader, dio::Diorama)
    for prog in components(dio, RenderProgram)
    	if isempty(prog)
        	ProgType = eltype(prog)
    		dio[Entity(1)] = ProgType(Program(shaders(ProgType)))
    	end
	end
end

function Overseer.update(::Uploader, m::AbstractLedger)
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
    for e in @entities_in(line_geom)
        e_geom = line_geom[e]
        vert_loc = attribute_location(line_prog.program, :vertices)
        color_loc = attribute_location(line_prog.program, :color)

        if e in ucolor
            color_vec = fill(ucolor[e].color, length(e_geom.points))
        elseif e in bcolor
            color_vec = bcolor[e].color
        else
            continue
        end

        if !(e in line_vao)
            color_attach = BufferAttachmentInfo(:color, color_loc, Buffer(color_vec), GEOMETRY_DIVISOR)
            points_attach = BufferAttachmentInfo(:vertices, vert_loc, Buffer(e_geom.points), GEOMETRY_DIVISOR)
            line_vao[e] = LineVao(VertexArray([points_attach, color_attach], GL_LINE_STRIP_ADJACENCY), true)
        else
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :vertices).buffer, e_geom.points)
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :color).buffer, color_vec)
        end
    end
    empty!(line_geom)
end

struct InstancedUploader <: System end

function Overseer.update(::InstancedUploader, m::AbstractLedger)
	default_prog = m[InstancedDefaultProgram][1].program	
	peeling_prog = m[InstancedPeelingProgram][1].program	
	default_vao  = m[InstancedDefaultVao]
	peeling_vao  = m[InstancedPeelingVao]
	idc = m[IDColor]
	mesh = m[Mesh]
	if isempty(mesh)
		return
	end
	ucolor = m[UniformColor]
	modelmat = m[ModelMat]
	material = m[Material]
    alpha = m[Alpha]


	default_it   = @entities_in(!default_vao && mesh && ucolor && modelmat && material && !alpha)
	peeling_it   = @entities_in(!peeling_vao && mesh && ucolor && modelmat && material && alpha)

	timing = singleton(m, TimingData).timer
	if iterate(default_it) === nothing && iterate(peeling_it) === nothing
    	return
	end

    get_uniforms = (it, tmesh) -> begin
		modelmats = Mat4f0[]
		specints  = Float32[]
		specpows  = Float32[]
		ids       = Entity[]
		colors    = RGBf0[]
		idcolors  = RGBf0[]
		for e in it
    		e_mesh, e_modelmat, e_material, e_color = mesh[e], modelmat[e], material[e], ucolor[e]
    		if e_mesh === tmesh
        		push!(modelmats, e_modelmat.modelmat)
        		push!(specints,  e_material.specint)
        		push!(specpows,  e_material.specpow)
        		push!(colors, e_color.color)
        		if e ∈ idc
            		push!(idcolors,  idc[e].color)
        		else
            		push!(idcolors, RGBf0(1,1,1))
        		end
        		push!(ids, e)
    		end
		end
		return modelmats, specints, specpows, colors, idcolors, ids
	end

	for tmesh in mesh.shared
    	default_modelmats, default_specints, default_specpows, default_colors, default_idcolors, default_ids = get_uniforms(default_it, tmesh)
    	peeling_modelmats, peeling_specints, peeling_specpows, peeling_colors, peeling_idcolors, peeling_ids = get_uniforms(peeling_it, tmesh)
		if !isempty(default_ids)
            indices = tmesh.mesh.faces .- GLint(1)
    		buffers = [generate_buffers(default_prog, tmesh.mesh);
                       generate_buffers(default_prog, GLA.UNIFORM_DIVISOR,
                                        color    = default_colors,
                                        modelmat = default_modelmats,
                                        specint  = default_specints,
                                        specpow  = default_specpows,
                                        object_id_color = default_idcolors,
                                        )]
			tvao = InstancedDefaultVao(VertexArray(buffers, indices, length(default_ids)), true)
			for e in default_ids
    			default_vao[e] = tvao
			end
		end
		if !isempty(peeling_ids)
    		alphas = [alpha[e].α for e in peeling_ids]
            indices = tmesh.mesh.faces .- GLint(1)
    		buffers = [generate_buffers(peeling_prog, tmesh.mesh);
                       generate_buffers(peeling_prog, GLA.UNIFORM_DIVISOR,
                                        color    = peeling_colors,
                                        modelmat = peeling_modelmats,
                                        specint  = peeling_specints,
                                        specpow  = peeling_specpows,
                                        object_id_color = peeling_idcolors,
                                        alpha = alphas)]
			tvao = InstancedPeelingVao(VertexArray(buffers, indices, length(peeling_ids)), true)
			for e in peeling_ids
    			peeling_vao[e] = tvao
			end
		end
	end
end

struct UniformUploader <: System end

Overseer.requested_components(::UniformUploader) =
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

function Overseer.update(::UniformUploader, m::AbstractLedger)
	uc = m[UpdatedComponents][1]
	mat = m[ModelMat]
	matsize = sizeof(eltype(mat))
	for vao in (m[InstancedDefaultVao], m[InstancedPeelingVao])
    	if ModelMat in uc
        	it1 = @entities_in(vao && mat)
    		for tvao in vao.shared
    			modelmats = ModelMat[]

    			@timeit debug_timer(m) "mat creating" for e in it1
                    e_vao, e_modelmat = vao[e], mat[e]
    				if e_vao === tvao
    					push!(modelmats, e_modelmat)
    				end
    			end
    			@timeit debug_timer(m) "uploading" if !isempty(modelmats)
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
        	colsize = sizeof(RGBf0)
        	it2 = @entities_in(vao && m[UniformColor] && m[Selectable])
    		for tvao in vao.shared
    			colors = RGBf0[]
    			for e in it2
        			e_vao, e_color, = vao[e], ucolor[e]
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
