#Came from GLAbstraction/GLUtils.jl
#question: Used?
function close_to_square(n::Real)
    # a cannot be greater than the square root of n
    # b cannot be smaller than the square root of n
    # we get the maximum allowed value of a
    amax = floor(Int, sqrt(n));
    if 0 == rem(n, amax)
        # special case where n is a square number
        return (amax, div(n, amax))
    end
    # Get its prime factors of n
    primeFactors  = factor(n);
    # Start with a factor 1 in the list of candidates for a
    candidates = Int[1]
    for (f, _) in primeFactors
        # Add new candidates which are obtained by multiplying
        # existing candidates with the new prime factor f
        # Set union ensures that duplicate candidates are removed
        candidates  = union(candidates, f .* candidates);
        # throw out candidates which are larger than amax
        filter!(x-> x <= amax, candidates)
    end
    # Take the largest factor in the list d
    (candidates[end], div(n, candidates[end]))
end

#Came from GLAbstraction/GLCamera.jl
w_component(::Point{N, T}) where {N, T} = T(1)
w_component(::Vec{N, T}) where {N, T} = T(0)