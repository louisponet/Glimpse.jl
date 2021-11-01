
# Masked Arrays are used in systems
struct Mask
    start :: Int
    len   :: Int
end

function Base.sum(v::Vector{Mask})
    t = 0
    for g in v
        t += g.len
    end
    return t
end

struct MaskedArray{T,N} <: AbstractArray{T,N}
    base::DenseArray{T,N}
    masks::Vector{Mask}
end

function masked_index(A::MaskedArray, i::Int)
    t_id = i
    for g in A.masks
        if t_id >= g.start
            t_id += g.len
        end
    end
    return t_id
end

Base.size(A::MaskedArray)                 = size(A.base) .- sum(A.masks)
Base.length(A::MaskedArray)               = length(A.base) .- sum(A.masks)
Base.getindex(A::MaskedArray, i::Int)     = A.base[masked_index(A, i)]
Base.setindex!(A::MaskedArray, v, i::Int) = A.base[masked_index(A, i)] = v
Base.IndexStyle(::Type{<:MaskedArray})    = IndexLinear()
