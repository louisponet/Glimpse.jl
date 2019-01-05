"""
    separate!(f, A::AbstractVector{T}) where T

Separates the true part from `A`, leaving the false part in `A`.
Single values get passed into `f`.
"""
function separate!(f, A::AbstractVector{T}) where T
    trues = f.(A)
    return A[trues], deleteat!(A, trues)
end
