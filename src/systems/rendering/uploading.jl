struct Uploader{P <: ProgramKind} <: System
	data ::SystemData
end

Uploader(::Type{P}, dio::Diorama) where {P<:ProgramKind} = 
	Uploader{P}(SystemData(dio, (Mesh, BufferColor, Vao{P}, ProgramTag{P}), (RenderProgram{P},)))

InstancedUploader(::Type{P}, dio::Diorama) where {P<:ProgramKind} =
	Uploader{P}(SystemData(dio, (Mesh,
				      	         UniformColor,
				      	         ModelMat,
				      	         Material,
				      	         Vao{P},
				      	         ProgramTag{P},
			      	            ), (RenderProgram{P},)))


function update_indices!(uploader::Uploader{K}) where {K <: Union{DefaultProgram, PeelingProgram, LineProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	progtag  = comp(ProgramTag{K})

	uploaded_entities = valid_entities(comp(Vao{K}))
	uploader.data.indices  = [setdiff(valid_entities(progtag, comp(Mesh)), uploaded_entities),
	                          setdiff(valid_entities(progtag, scomp(Mesh)),  uploaded_entities),
	                          valid_entities(comp(BufferColor))]
end

function update(uploader::Uploader{K}) where {K <: Union{DefaultProgram, PeelingProgram, LineProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	bcolor   = comp(BufferColor)
	mesh     = comp(Mesh)
	vao      = comp(Vao{K})
	prog     = singleton(uploader, RenderProgram{K})
	progtag  = comp(ProgramTag{K})
	smesh    = scomp(Mesh)
	for (i, m) in enumerate((mesh, smesh))
		for e in indices(uploader)[i]
			if e ∈ indices(uploader)[end]
				buffers = [generate_buffers(prog.program, m[e].mesh); generate_buffers(prog.program, GEOMETRY_DIVISOR, color=bcolor[e].color)]
		    else
			    buffers = generate_buffers(prog.program, m[e].mesh)
		    end
		    if K == LineProgram
			    vao[e] = Vao{K}(VertexArray(buffers, 11), true)
		    else
			    vao[e] = Vao{K}(VertexArray(buffers, faces(m[e].mesh) .- GLint(1)), true)
		    end
	    end
	end
end

function update_indices!(uploader::Uploader{K}) where {K <: Union{DefaultInstancedProgram, PeelingInstancedProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	smesh    = scomp(Mesh)
	ivao     = scomp(Vao{K})
	iprog    = singleton(uploader, RenderProgram{K})
	iprogtag = comp(ProgramTag{K})
	modelmat = comp(ModelMat)
	material = comp(Material)
	ucolor   = comp(UniformColor)
	uploader.data.indices = [setdiff(valid_entities(iprogtag, smesh, modelmat, material, ucolor), valid_entities(ivao))]
	for m in smesh.shared
		push!(uploader.data.indices, shared_entities(smesh, m) ∩ indices(uploader)[1])
	end
end

function update(uploader::Uploader{K}) where {K <: Union{DefaultInstancedProgram, PeelingInstancedProgram}}
	comp(T)  = component(uploader, T)
	scomp(T) = shared_component(uploader, T)

	smesh    = scomp(Mesh)
	ivao     = scomp(Vao{K})
	iprog    = singleton(uploader, RenderProgram{K})
	iprogtag = comp(ProgramTag{K})
	modelmat = comp(ModelMat)
	material = comp(Material)
	ucolor   = comp(UniformColor)

	instanced_entities = indices(uploader)[1]
	if isempty(instanced_entities)
		return
	end
	for (i, m) in enumerate(smesh.shared)
		t_es = indices(uploader)[i+1]
		if !isempty(t_es)
			modelmats = Vector{Mat4f0}(undef,  length(t_es))
			ucolors   = Vector{RGBAf0}(undef,  length(t_es))
			specints  = Vector{Float32}(undef, length(t_es))
			specpows  = Vector{Float32}(undef, length(t_es))

			for (i, e) in enumerate(t_es)
				modelmats[i] = modelmat[e].modelmat
				specints[i]  = material[e].specint
				specpows[i]  = material[e].specpow
				ucolors[i]   = ucolor[e].color
			end
			tprog = iprog.program
			tmesh = smesh[t_es[1]].mesh
		    push!(ivao.shared, Vao{K}(VertexArray([generate_buffers(tprog, tmesh); generate_buffers(tprog, GLint(1), color=ucolors, modelmat=modelmats, specint=specints, specpow=specpows)], tmesh.faces .- GLint(1), length(t_es)), true))
		    for e in t_es
			    ivao.data[e] = length(ivao.shared)
		    end
	    end
	end
end

struct UniformUploader <: System
	data ::SystemData

	UniformUploader(dio::Diorama) = new(SystemData(dio, (Vao{DefaultInstancedProgram},
                                                         Vao{PeelingInstancedProgram},
                                                         ModelMat),
                                                        (UpdatedComponents,)))
end

function update_indices!(sys::UniformUploader)
	mat_entities = valid_entities(component(sys, ModelMat))
	dvao         = shared_component(sys, Vao{DefaultInstancedProgram})
	pvao         = shared_component(sys, Vao{PeelingInstancedProgram})
	tids = Vector{Int}[]
	for v in dvao.shared 
		push!(tids, shared_entities(dvao, v) ∩ mat_entities)
	end
	for v in pvao.shared 
		push!(tids, shared_entities(pvao, v) ∩ mat_entities)
	end
	sys.data.indices = tids                       
end

function find_contiguous_bounds(indices)
	ranges = UnitRange[]
	i = 1
	cur_start = indices[1]
	while i <= length(indices) - 1
		id = indices[i]
		id_1 = indices[i + 1]
		if id_1 - id != 1
			push!(ranges, cur_start:id)
			cur_start = id_1
		end
		i += 1
	end
	push!(ranges, cur_start:indices[end])
	return ranges
end

function update(sys::UniformUploader)
	uc = singleton(sys, UpdatedComponents)
	dvao = shared_component(sys, Vao{DefaultInstancedProgram})
	pvao = shared_component(sys, Vao{PeelingInstancedProgram})

	mat = component(sys, ModelMat)
	matsize = sizeof(eltype(mat))
	indices_id = 1
	if ModelMat in uc.components
		upload = instanced_vao -> begin
			for v in instanced_vao.shared
				eids = indices(sys)[indices_id]
				contiguous_ranges = find_contiguous_bounds(eids)
				offset = 0
				if !isempty(eids)
					binfo = GLA.bufferinfo(v.vertexarray, :modelmat)
					if binfo != nothing
						GLA.bind(binfo.buffer)
						for r in contiguous_ranges
							s = length(r) * matsize
							glBufferSubData(binfo.buffer.buffertype, offset, s, pointer(mat, r[1]))
							offset += s
						end
						GLA.unbind(binfo.buffer)
					end
				end
			end
		end
		upload(dvao)
		upload(pvao)
	end
end
