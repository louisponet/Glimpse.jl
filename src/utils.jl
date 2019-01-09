"""
    separate!(f, A::AbstractVector{T}) where T

Separates the true part from `A`, leaving the false part in `A`.
Single values get passed into `f`.
"""
function separate!(f, A::AbstractVector{T}) where T
    trues = f.(A)
    return A[trues], deleteat!(A, trues)
end

fillmutable(mutable, size::Int) = size==1 ? [mutable] : [mutable ; [deepcopy(mutable) for i=2:size]]
