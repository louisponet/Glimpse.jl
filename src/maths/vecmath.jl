function normalizeperp(vec1::Vec3{T}, vec2::Vec3{T}) where {T}
    if dot(vec1, vec2) == 0
        return vec2
    else
        return normalize(Vec3{T}(vec2[1], vec2[2],
                                 (-vec1[1] * vec2[1] - vec1[2] * vec2[2]) /
                                 (vec1[3] + 0.001)))
    end
end
