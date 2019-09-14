
struct Uploader{P <: ProgramKind} <: System end

requested_components(::Uploader{P}) where {P<:Union{DefaultProgram,PeelingProgram}} =
	(Mesh, BufferColor, Vao{P}, ProgramTag{P}, RenderProgram{P})

requested_components(::Uploader{P}) where {P<:Union{InstancedDefaultProgram,InstancedPeelingProgram}} =
	(Mesh, UniformColor, ModelMat, Material, Vao{P}, ProgramTag{P}, RenderProgram{P})

shaders(::Type{DefaultProgram}) = default_shaders()
shaders(::Type{PeelingProgram}) = peeling_shaders()

function ECS.prepare(::Uploader{P}, dio::Diorama) where {P<:Union{DefaultProgram,PeelingProgram}}
	if isempty(dio[RenderProgram{P}])
		Entity(dio, RenderProgram{P}(Program(shaders(P))))
	end
end

function (::Uploader{P})(m) where {P<:Union{DefaultProgram,PeelingProgram}}

	mesh, bcolor, vao, progtag, prog = m[Mesh], m[BufferColor], m[Vao{P}], m[ProgramTag{P}], m[RenderProgram{P}][1].program

	set_vao = (e, buffers, e_mesh) -> begin
	    if P == LineProgram
		   vao[e] = Vao{P}(VertexArray(buffers, 11), true)
	    else
		    vao[e] = Vao{P}(VertexArray(buffers, faces(e_mesh.mesh) .- GLint(1)), true)
	    end
    end
	it1 = zip(mesh, progtag, exclude=(vao,))
	for (e_mesh, t) in it1
		buffers = generate_buffers(prog, e_mesh.mesh)
		set_vao(Entity(it1), buffers, e_mesh)
	end

	it2 = zip(mesh, progtag, bcolor, exclude=(vao,))
	for (e_mesh, t, e_color) in it2
		buffers = [generate_buffers(prog, e_mesh.mesh);
	               generate_buffers(prog, GEOMETRY_DIVISOR, color=e_color.color)]
		set_vao(Entity(it2), buffers, e_mesh)
	end
end

# function update_indices!(uploader::Uploader{K}) where {K <: Union{InstancedDefaultProgram, PeelingInstancedProgram}}
# 	comp(T)  = component(uploader, T)
# 	scomp(T) = shared_component(uploader, T)

# 	smesh    = scomp(Mesh)
# 	ivao     = scomp(Vao{K})
# 	iprog    = singleton(uploader, RenderProgram{K})
# 	iprogtag = comp(ProgramTag{K})
# 	modelmat = comp(ModelMat)
# 	material = comp(Material)
# 	ucolor   = comp(UniformColor)
# 	uploader.data.indices = [setdiff(valid_entities(iprogtag, smesh, modelmat, material, ucolor), valid_entities(ivao))]
# 	for m in smesh.shared
# 		push!(uploader.data.indices, shared_entities(smesh, m) ∩ indices(uploader)[1])
# 	end
# end


shaders(::Type{InstancedDefaultProgram}) = instanced_default_shaders()
shaders(::Type{InstancedPeelingProgram}) = instanced_peeling_shaders()


function ECS.prepare(::Uploader{P}, dio::Diorama) where {P<:Union{InstancedDefaultProgram, InstancedPeelingProgram}}
	if isempty(dio[RenderProgram{P}])
		Entity(dio, RenderProgram{P}(Program(shaders(P))))
	end
end

function (::Uploader{P})(m) where {P <: Union{InstancedDefaultProgram, InstancedPeelingProgram}}
	prog = m[RenderProgram{P}][1].program	
	vao = m[Vao{P}]
	mesh = m[Mesh]
	it = zip(mesh, m[UniformColor], m[ModelMat], m[Material], m[ProgramTag{P}], exclude=(vao,))
	if isempty(mesh)
		return
	end
	stor = ECS.storage(vao)
	for tmesh in mesh.shared
		modelmats = Mat4f0[]
		ucolors   = RGBAf0[]
		specints  = Float32[]
		specpows  = Float32[]
		ids  = Int[]
		for (e_mesh, e_color, e_modelmat, e_material, t) in it
			if e_mesh.mesh === tmesh.mesh
				push!(modelmats, e_modelmat.modelmat)
				push!(ucolors, e_color.color)
				push!(specints, e_material.specint)
				push!(specpows, e_material.specpow)
				push!(ids, ECS.id(ECS.Entity(it)))
			end
			tvao = Vao{P}(VertexArray([generate_buffers(prog, tmesh.mesh); generate_buffers(prog, GLint(1), color=ucolors, modelmat=modelmats, specint=specints, specpow=specpows)], tmesh.mesh.faces .- GLint(1), length(ids)), true)
			push!(vao.shared, tvao)
			id = length(vao.shared)
			for i in ids
				stor[i, ECS.Reverse()] = id
			end
		end
	end
end

# struct UniformUploader{P<:ProgramKind} <: System
# 	data ::SystemData

# 	function UniformUploader{P}(dio::Diorama) where {P<:ProgramKind}
# 		components = (Vao{P}, ModelMat, Selectable, UniformColor)
# 		new{P}(SystemData(dio, components, (UpdatedComponents,)))
# 	end
# end

# function update_indices!(sys::UniformUploader{P}) where {P<:ProgramKind}
# 	mat_entities = valid_entities(sys, ModelMat)
# 	sel_col_entities = valid_entities(sys, UniformColor, Selectable)
# 	vao         = shared_component(sys, Vao{P})
# 	tids = Vector{Int}[]
# 	for v in vao.shared 
# 		push!(tids, shared_entities(vao, v) ∩ mat_entities)
# 	end
# 	for v in vao.shared 
# 		push!(tids, shared_entities(vao, v) ∩ sel_col_entities)
# 	end
# 	sys.data.indices = tids                       
# end

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

# function update(sys::UniformUploader{P}) where {P<:ProgramKind}
# 	uc = singleton(sys, UpdatedComponents)
# 	vao = shared_component(sys, Vao{P})

# 	mat = component(sys, ModelMat)
# 	matsize = sizeof(eltype(mat))
# 	idoffset = 0
# 	if ModelMat in uc.components
# 		for (i, v) in enumerate(vao.shared)
# 			eids = indices(sys)[i]
# 			contiguous_ranges = find_contiguous_bounds(eids)
# 			offset = 0
# 			if !isempty(eids)
# 				binfo = GLA.bufferinfo(v.vertexarray, :modelmat)
# 				if binfo != nothing
# 					GLA.bind(binfo.buffer)
# 					for r in contiguous_ranges
# 						s = length(r) * matsize
# 						glBufferSubData(binfo.buffer.buffertype, offset, s, pointer(mat, r[1]))
# 						offset += s
# 					end
# 					GLA.unbind(binfo.buffer)
# 				end
# 			end
# 			idoffset += 1
# 		end
# 	end

# 	col = component(sys, UniformColor)
# 	colsize = sizeof(eltype(col))
# 	#TODO Optimization: Color of all selectable entities is updated at the same time.
# 	if Selectable in uc.components
# 		for (i, v) in enumerate(vao.shared)
# 			eids = indices(sys)[i+idoffset]
# 			contiguous_ranges = find_contiguous_bounds(eids)
# 			offset = 0
# 			if !isempty(eids)
# 				binfo = GLA.bufferinfo(v.vertexarray, :color)
# 				if binfo != nothing
# 					GLA.bind(binfo.buffer)
# 					for r in contiguous_ranges
# 						s = length(r) * colsize
# 						glBufferSubData(binfo.buffer.buffertype, offset, s, pointer(col, r[1]))
# 						offset += s
# 					end
# 					GLA.unbind(binfo.buffer)
# 				end
# 			end
# 		end
# 	end
# end
