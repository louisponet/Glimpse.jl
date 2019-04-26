mutable struct GappedVector{T} <: AbstractVector{T}
	data::Vector{Vector{T}}
	start_ids::Vector{Int}
	function GappedVector(vecs::Vector{Vector{T}}, start_ids::Vector{Int}) where T
		totlen = 0
		if !in(1, start_ids)
			prepend!(start_ids, 1)
		end
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
Base.length(A::GappedVector) = A.start_ids[end] + length(A.data[end]) - 1

Base.isempty(A::GappedVector) = length(A) == 0
Base.empty!(A::GappedVector{T}) where T = (A.start_ids = Int[1]; A.data = [T[]])
# Base.push!(A::GappedVector{T}, x) where T = A[end+1] = convert(T, x)

@timeit to function Base.getindex(A::GappedVector, i::Int)
	for (s_id, bvec) in zip(A.start_ids, A.data)
		if s_id <= i < s_id + length(bvec)
			return bvec[i - s_id + 1]
		end
	end
	error("Gapped out of bounds.")
end

@timeit to function overwrite!(A::GappedVector{T}, v::T, i::Int) where T
	for (startid, bvec) in zip(A.start_ids, A.data)
		endid   = startid + length(bvec)
		if startid <= i < endid # overwrite
			bvec[i - startid + 1] = v
		end
	end
end

@timeit to function Base.setindex!(A::GappedVector{T}, v, i::Int) where T
	# conv_v = convert(T, v)
	conv_v = v

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
				insert!(bvec, i, conv_v)
				startid -= 1
				handled = true
				break
			end
		end
		if !handled
			add!()
		end
		sort!(A)
		clean!(A)
		return conv_v
	end
end

function Base.sort!(A::GappedVector)
	p = zeros(Int, length(A.start_ids))
	sortperm!(p, A.start_ids)
	A.data      .= A.data[p]
	A.start_ids .= A.start_ids[p]
end

function clean!(A::GappedVector)
	#TODO Performance: This should maybe be saved for a manual clean?
	ids_to_remove = Int[]
	for (i, bvec) in enumerate(A.data)
		if isempty(bvec)
			push!(ids_to_remove, i)
		end
	end
	for i in reverse(sort(ids_to_remove))
		deleteat!(A.data, i)
		deleteat!(A.start_ids, i)
	end

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

#does nothing when it doesn't have the index i
function remove_entry!(A::GappedVector, i::Int)
	val = A[i]
	for (vid, (startid, bvec)) in enumerate(zip(A.start_ids, A.data))
		endid   = startid + length(bvec)
		if startid < i < endid - 1 #insert new vector
			push!(A.start_ids, i+1)
			push!(A.data, bvec[i - startid + 2:end]) 
			A.data[vid] = bvec[1:i - startid]
		elseif i == endid - 1 #remove last element
			pop!(bvec)
		elseif i == startid #reseat one element over
			A.start_ids[vid] = startid + 1
			A.data[vid]      = bvec[2:end]
		end
	end
	sort!(A)
	clean!(A)
	return val
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

function has_index(A::GappedVector, i)
	for (sid, vec) in zip(A.start_ids, A.data)
		if  sid <= i < sid + length(vec)
			return true
		end
	end
	return false
end


function Base.eachindex(A::GappedVector)
	t_r = Int[]
	if isempty(A)
		return t_r
	else
		for (sid, vec) in zip(A.start_ids, A.data)
			append!(t_r, collect(sid : (sid+length(vec)-1)))
		end
		return t_r
	end
end


#TODO Performance: this can be optimized quite a bit
ranges(A::GappedVector) = [sid:sid + length(vec) - 1  for (sid, vec) in zip(A.start_ids, A.data)]
ranges(As::GappedVector...) = find_overlaps(ranges.(As))

@timeit to function find_overlaps(ranges)
	out_ranges = UnitRange{Int}[]
	for r1 in ranges[1], r2 in ranges[2]
		tr = intersect(r1, r2)
		if !isempty(tr)
			push!(out_ranges, tr)
		end
	end
	return out_ranges
end

@timeit to function find_overlaps(rangevecvec::Vector{Vector{UnitRange{Int}}})
	rs = rangevecvec[1]
	for rs2 in rangevecvec[2:end]
		rs = find_overlaps(rs, rs2)
	end
	return rs
end


function Base.show(io::IO, g::GappedVector{T}) where T
	println(io, "GappedVector{$T}")
	println(io, "\tlength: $(length(g))")
	println(io, "\tstartids: $(g.start_ids)")
end
