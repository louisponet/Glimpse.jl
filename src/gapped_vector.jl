struct GappedVector{T} <: AbstractVector{T}
	data::Vector{Vector{T}}
	start_ids::Vector{Int}
	function GappedVector(vecs::Vector{Vector{T}}, start_ids::Vector{Int}) where T
		totlen = 0
		# Check that no overlaps would happen
		for (vec, sid) in zip(vecs, start_ids)
			if sid > totlen
				totlen += sid + length(vec) - 1
			else
				error("start id $sid would result in overlapping vectors, this is not allowed")
			end
		end
		return new{T}(vecs, start_ids)
	end
end

Base.size(A::GappedVector)   = (length(A),)
Base.length(A::GappedVector) =  A.start_ids[end] + length(A.data[end]) - 1

function Base.getindex(A::GappedVector, i::Int)
	for (s_id, bvec) in zip(A.start_ids, A.data)
		if s_id <= i < s_id + length(bvec)
			return bvec[i - s_id + 1]
		end
	end
	error("Gapped out of bounds.")
end

function Base.setindex!(A::GappedVector{T}, v, i::Int) where T
	conv_v = convert(T, v)

	function add!()
		push!(A.data, [conv_v])
		push!(A.start_ids, i)
	end

	if i == length(A) + 1
		append!(A.data[end], conv_v)
	elseif i > length(A) + 1
		add!()
	else
		handled = false
		for (startid, bvec) in zip(A.start_ids, A.data)
			endid   = startid + length(bvec)
			if startid <= i < endid # overwrite
				bvec[i - startid + 1] = conv_v
				handled = true
				break
			elseif i == endid # grow right
				append!(bvec, conv_v)
				handled = true
				break
			elseif i == startid - 1 # grow left
				prepend!(bvec, conv_v)
				startid -= 1
				handled = true
				break
		# elseif endid < i < A.start_ids[vid+1] - 1 # insert new vec in a gap
			# 	add!()
			# 	handled = true
			# 	break
			end
		end
		if !handled
			add!()
		end

		p = zeros(Int, length(A.start_ids))
		sortperm!(p, A.start_ids)
		A.data      .= A.data[p]
		A.start_ids .= A.start_ids[p]

		#TODO Performance: This should maybe be saved for a manual clean?
		vid = 1
		while vid < length(A.data)
			startid = A.start_ids[vid]
			bvec    = A.data[vid]
			if startid + length(bvec) == A.start_ids[vid+1]
				append!(bvec, A.data[vid+1])
				deleteat!(A.data, vid+1)
				deleteat!(A.start_ids, vid+1)
				break
			else
				vid += 1
			end
		end
	end
	return conv_v
end

Base.IndexStyle(::Type{<:GappedVector}) = IndexLinear()

function Base.iterate(A::GappedVector, state=(1,1))
	if state[1] > length(A.data)
		return nothing
	elseif state[2] == length(A.data[state[1]])
		return A.data[state[1]][state[2]], (state[1]+1, 1)
	else
		return A.data[state[1]][state[2]], (state[1], state[2]+1)
	end
end

Base.isempty(A::GappedVector) = isempty(A.start_ids)

function Base.eachindex(A::GappedVector)
	if isempty(A)
		return Int[]
	else
		t_r = collect(A.start_ids[1]:length(A.data[1]))
		for i=2:length(A.start_ids)
			append!(t_r, collect(A.start_ids[i]:length(A.data[i])))
		end
		return t_r
	end
end

Base.push!(A::GappedVector{T}, x) where T = A[end+1] = convert(T, x)

function has_index(A::GappedVector, i)
	for (sid, vec) in zip(A.start_ids, A.data)
		if  sid <= i < sid + length(vec)
			return true
		end
	end
	return false
end

#TODO Performance: this can be optimized quite a bit
shared_indices(As::GappedVector...) = intersect(eachindex.(As)...)


struct SharedIterator{T}
	data::T
end

length(it::SharedIterator) = length(it.data)
function Base.iterate(it::SharedIterator, state=(ones(Int, length(it)), ones(Int, length(it)))
	for (vid, gvec) in zip(state[1], it.data)
		if vid > length(gvec.data)
			return nothing
		end
	if state[1] > length(A.data)
		return nothing
	elseif state[2] == length(A.data[state[1]])
		return A.data[state[1]][state[2]], (state[1]+1, 1)
	else
		return A.data[state[1]][state[2]], (state[1], state[2]+1)
	end
end
	

