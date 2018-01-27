#These are functions that I couldn't find uses for. I guess the main question is: do we keep these? 


#Came from: GLAbstraction/GLUtils.jl

struct IterOrScalar{T}
    val::T
end

minlenght(a::Tuple{Vararg{IterOrScalar}}) = foldl(typemax(Int), a) do len, elem
    isa(elem.val, AbstractArray) && len > length(elem.val) && return length(elem.val)
    len
end
getindex(A::IterOrScalar{T}, i::Integer) where {T<:AbstractArray} = A.val[i]
getindex(A::IterOrScalar, i::Integer) = A.val

#Some mapping functions for dictionaries
function mapvalues(func, collection::Dict)
    Dict([(key, func(value)) for (key, value) in collection])
end

function mapkeys(func, collection::Dict)
    Dict([(func(key), value) for (key, value) in collection])
end

