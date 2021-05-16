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

# @component struct AABB
#     origin  ::Vec3f0
#     diagonal::Vec3f0
# end

# function aabb_ray_intersect(aabb::AABB, entity_pos::Point3f0, ray_origin::Point3f0, ray_direction::Vec3f0)
#     dirfrac = 1.0f0 ./ ray_direction
#     right   = aabb.origin + aabb.diagonal

#     real_origin = aabb.origin + entity_pos
#     real_right  = right + entity_pos
#     t1 = (real_origin - ray_origin) .* dirfrac
#     t2 = (real_right - ray_origin)  .* dirfrac
#     tsmaller = min.(t1, t2)
#     tbigger  = max.(t1,t2)

#     tmin = maximum(tsmaller)
#     tmax = minimum(tbigger)
    

#     return tmin < tmax
# end

