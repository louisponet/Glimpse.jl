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
shaders(::Type{FXAAProgram})  = fxaa_shaders()
#TODO there is some preparation doubling here!

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
    peeling_prog= singleton(m, PeelingProgram)
    default_prog= singleton(m, DefaultProgram)
    line_prog   = singleton(m, LineProgram)
    uc = singleton(m, UpdatedComponents)
    alpha = m[Alpha]

    #Buffer color entities are always not instanced
    for e in @entities_in(mesh && bcolor && !default_vao && !peeling_vao)
        e_mesh = mesh[e]
        e_color = bcolor[e].color
        gen_vao = prog -> begin
    		buffers = [generate_buffers(prog, e_mesh.mesh);
    	               generate_buffers(prog, GEOMETRY_DIVISOR, color=e_color)]
            return VertexArray(buffers, faces(e_mesh.mesh) .- GLint(1))
        end

        if e in alpha && alpha[e].α < 1
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
		materials  = Material[]
		ids       = Entity[]
		colors    = RGBf0[]
		idcolors  = RGBf0[]
		for e in it
    		e_mesh, e_modelmat, e_material, e_color = mesh[e], modelmat[e], material[e], ucolor[e]
    		if e_mesh === tmesh
        		push!(modelmats, e_modelmat.modelmat)
        		push!(materials,  e_material)
        		push!(colors, e_color.color)
        		if e ∈ idc
            		push!(idcolors,  idc[e].color)
        		else
            		push!(idcolors, RGBf0(1,1,1))
        		end
        		push!(ids, e)
    		end
		end
		return modelmats, materials, colors, idcolors, ids
	end

	for tmesh in mesh.shared
    	default_modelmats, default_materials, default_colors, default_idcolors, default_ids = get_uniforms(default_it, tmesh)
    	peeling_modelmats, peeling_materials, peeling_colors, peeling_idcolors, peeling_ids = get_uniforms(peeling_it, tmesh)
		if !isempty(default_ids)
            indices = map(x->x.-GLint(1), tmesh.mesh.faces)
    		buffers = [generate_buffers(default_prog, tmesh.mesh);
                       generate_buffers(default_prog, GLA.UNIFORM_DIVISOR,
                                        color    = default_colors,
                                        modelmat = default_modelmats,
                                        material  = default_materials,
                                        object_id_color = default_idcolors,
                                        )]
			tvao = InstancedDefaultVao(VertexArray(buffers, indices, length(default_ids)), true)
			for e in default_ids
    			default_vao[e] = tvao
			end
		end
		if !isempty(peeling_ids)
    		alphas = [alpha[e].α for e in peeling_ids]
            indices = map(x->x.-GLint(1), tmesh.mesh.faces)
    		buffers = [generate_buffers(peeling_prog, tmesh.mesh);
                       generate_buffers(peeling_prog, GLA.UNIFORM_DIVISOR,
                                        color    = peeling_colors,
                                        modelmat = peeling_modelmats,
                                        material  = peeling_materials,
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
    ucolor = m[UniformColor]
    material = m[Material]
	for vao in (m[InstancedDefaultVao], m[InstancedPeelingVao])
    	reupload_uniform_component = (comp, comp_shader_symbol) -> begin
    	    datsize = sizeof(eltype(comp))
        	it1 = @entities_in(vao && comp)
    		for tvao in vao.shared
    			comp_vector = eltype(comp)[]

    			for e in it1
                    e_vao, e_comp = vao[e], comp[e]
    				if e_vao === tvao
    					push!(comp_vector, e_comp)
    				end
    			end
    			if !isempty(comp_vector)
    				binfo = GLA.bufferinfo(tvao.vertexarray, comp_shader_symbol)
    				if binfo !== nothing
    					GLA.bind(binfo.buffer)
    					s = length(comp_vector) * datsize
    					glBufferData(binfo.buffer.buffertype, s, pointer(comp_vector, 1), binfo.buffer.usage)
    					GLA.unbind(binfo.buffer)
    				end
    			end
    		end
    	end
    	if ModelMat in uc
        	reupload_uniform_component(m[ModelMat], :modelmat)
    	end
    	if UniformColor in uc.components
        	reupload_uniform_component(m[UniformColor], :color)
    	end
    	if Material in uc.components
        	reupload_uniform_component(m[Material], :material)
        end
    	if Alpha in uc.components
        	reupload_uniform_component(m[Alpha], :alpha)
        end	
	end
end
