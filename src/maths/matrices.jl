Eye4f0() = Mat4f0(Matrix(1.0f0I, 4, 4))
#Came from GLAbstraction/GLMatrixmath.jl
function scalemat(s::Vec{3,T}) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(s[1], T0, T0, T0, T0, s[2], T0, T0, T0, T0, s[3], T0, T0, T0, T0, T1)
end

function scalemat(s::T) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(s, T0, T0, T0, T0, s, T0, T0, T0, T0, s, T0, T0, T0, T0, T1)
end

scalemat(s::Point{3,T}) where {T} = scalemat(convert(Vec{3,T}, s))

translmat_x(x::T) where {T} = translmat(Vec{3,T}(x, 0, 0))
translmat_y(y::T) where {T} = translmat(Vec{3,T}(0, y, 0))
translmat_z(z::T) where {T} = translmat(Vec{3,T}(0, 0, z))

function translmat(t::Vec{3,T}) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(T1, T0, T0, T0, T0, T1, T0, T0, T0, T0, T1, T0, t[1], t[2], t[3], T1)
end
translmat(t::Point{3,T}) where {T} = translmat(convert(Vec{3,T}, t))

function rotate(a::Number, axis::Vec{3,T}) where {T}
    axis = normalize(axis)
    u, v, w = axis
    return Mat4{T}(u^2 + (1 - u^2) * cos(a), u * v * (1 - cos(a)) + w * sin(a),
                   u * w * (1 - cos(a)) - v * sin(a), 0.0,
                   u * v * (1 - cos(a)) - w * sin(a), v^2 + (1 - v^2) * cos(a),
                   v * w * (1 - cos(a)) + u * sin(a), 0.0,
                   u * w * (1 - cos(a)) + v * sin(a), v * w * (1 - cos(a)) - u * sin(a),
                   w^2 + (1 - w^2) * cos(a), 0.0, 0.0, 0.0, 0.0, 1.0)
end

function rotate(::Type{T}, angle::Number, axis::Vec{3}) where {T}
    return rotate(T(angle), convert(Vec{3,T}, axis))
end

function rotate(v1::T, angle::Number, axis) where {T<:StaticArray{Tuple{3}}}
    return T((rotate(angle, axis)*SVector{4}(v1..., 1.0))[1:3]...)
end
function rotate(v1::T, angle::Number, origin, axis) where {T<:StaticArray{Tuple{3}}}
    return T((translmat(origin)*rotate(angle, axis)*translmat(-origin)*SVector{4}(v1...,
                                                                                  1.0))[1:3]...)
end

function rotate(v1::Vec3{T}, v2::Vec3{T}) where {T}
    vr = v2 - v1
    l = norm(vr)
    angle = acos(vr[3] / l)
    axis = normalize(cross(Vec3(0.0000000001f0, 0.0f0, 1.0f0), vr))
    if length(axis) > 0.0001
        return rotate(angle, axis)
    end
    return Mat4(Eye4f0(T, 4))
end

function rotmat_x(angle::T) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(T1, T0, T0, T0, T0, cos(angle), sin(angle), T0, T0, -sin(angle),
                  cos(angle), T0, T0, T0, T0, T1)
end
function rotmat_y(angle::T) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(cos(angle), T0, -sin(angle), T0, T0, T1, T0, T0, sin(angle), T0,
                  cos(angle), T0, T0, T0, T0, T1)
end
function rotmat_z(angle::T) where {T}
    T0, T1 = zero(T), one(T)
    return Mat{4}(cos(angle), sin(angle), T0, T0, -sin(angle), cos(angle), T0, T0, T0, T0,
                  T1, T0, T0, T0, T0, T1)
end
"""
    Create view frustum

    Parameters
    ----------
        left : float
         Left coordinate of the field of view.
        right : float
         Left coordinate of the field of view.
        bottom : float
         Bottom coordinate of the field of view.
        top : float
         Top coordinate of the field of view.
        znear : float
         Near coordinate of the field of view.
        zfar : float
         Far coordinate of the field of view.

    Returns
    -------
        M : array
         View frustum matrix (4x4).
"""
function frustum(left::T, right::T, bottom::T, top::T, znear::T, zfar::T) where {T}
    (right == left || bottom == top || znear == zfar) && return Mat4{T}(I)
    T0, T1, T2 = zero(T), one(T), T(2)
    return Mat4{T}(T2 * znear / (right - left), T0, T0, T0, T0, T2 * znear / (top - bottom),
                   T0, T0, (right + left) / (right - left), (top + bottom) / (top - bottom),
                   -(zfar + znear) / (zfar - znear), -T1, T0, T0,
                   -(T2 * znear * zfar) / (zfar - znear), T0)
end

"""
`proj = projmatpersp([T], fovy, aspect, znear, zfar)` defines
a projection matrix with a given angular field-of-view `fovy` along
the y-axis (measured in degrees), the specified `aspect` ratio, and
near and far clipping planes `znear`, `zfar`. Optionally specify the
element type `T` of the matrix.
"""
function projmatpersp(fovy::T, aspect::T, znear::T, zfar::T) where {T}
    (znear == zfar) && error("znear ($znear) must be different from tfar ($zfar)")
    h = T(tan(fovy / 180.0 * pi) * znear)
    w = T(h * aspect)
    return frustum(-w, w, -h, h, znear, zfar)
end

function projmatpersp(w::Integer, h::Integer, fovy::T, znear::T, zfar::T) where {T}
    return projmatpersp(fovy, T(w / h), znear, zfar)
end

function projmatpersp(::Type{T}, fovy::Number, aspect::Number, znear::Number,
                      zfar::Number) where {T}
    return projmatpersp(T(fovy), T(aspect), T(znear), T(zfar))
end
"""
`proj = projmatpersp([T], rect, fov, near, far)` defines the
projection ratio in terms of the rectangular view size `rect` rather
than the aspect ratio.
"""
function projmatpersp(wh::Area, fov::T, near::T, far::T) where {T}
    return projmatpersp(fov, T(wh.w / wh.h), near, far)
end
function projmatpersp(::Type{T}, wh::Area, fov::Number, near::Number, far::Number) where {T}
    return projmatpersp(T(fov), T(wh.w / wh.h), T(near), T(far))
end

"""
`view = lookatmat(eyeposition, lookatmat, up)` creates a view matrix with
the eye located at `eyeposition` and looking at position `lookatmat`,
with the top of the window corresponding to the direction `up`. Only
the component of `up` that is perpendicular to the vector pointing
from `eyeposition` to `lookatmat` will be used.  All inputs must be
supplied as 3-vectors.
"""
function lookatmat(eyePos::Union{Vec{3,T},Point{3,T}}, lookAt::Union{Vec{3,T},Point{3,T}},
                   up::Union{Vec{3,T},Point{3,T}}) where {T}
    zaxis  = normalize(eyePos - lookAt)
    xaxis  = normalize(cross(up, zaxis))
    yaxis  = normalize(cross(zaxis, xaxis))
    T0, T1 = zero(T), one(T)
    return Mat{4}(xaxis[1], yaxis[1], zaxis[1], T0, xaxis[2], yaxis[2], zaxis[2], T0,
                  xaxis[3], yaxis[3], zaxis[3], T0, T0, T0, T0, T1) * translmat(-eyePos)
end
function lookatmat(eyePos, lookAt::Union{Vec{3,T},Point{3,T}},
                   up::Union{Vec{3,T},Point{3,T}}) where {T}
    return lookatmat(Vec{3,T}(eyePos), lookAt, up)
end
function lookatmat(::Type{T}, eyePos, lookAt::Vec{3}, up::Vec{3}) where {T}
    return lookatmat(Vec{3,T}(eyePos), Vec{3,T}(lookAt), Vec{3,T}(up))
end

"""
    projmatortho(left::T, right::T, bottom::T, top::T) where T

2D orthographic projection.
"""
function projmatortho(left::T, right::T, bottom::T, top::T) where {T}
    out = zeros(T, 4, 4)
    out[1, 1] = 2 / (right - left)
    out[2, 2] = 2 / (top - bottom)
    out[3, 3] = -1
    out[4, 1] = -(right + left) / (right - left)
    out[4, 2] = -(top + bottom) / (top - bottom)
    out[4, 4] = 1
    return Mat4{T}(out')
end

function projmatortho(::Type{T}, left::Number, right::Number, bottom::Number,
                      top::Number) where {T}
    return projmatortho(T(left), T(right), T(bottom), T(top))
end

function projmatortho(wh::Area, near::T, far::T) where {T}
    return projmatortho(zero(T), T(wh.w), zero(T), T(wh.h), near, far)
end
function projmatortho(::Type{T}, wh::Area, near::Number, far::Number) where {T}
    return projmatortho(wh, T(near), T(far))
end
function projmatortho(w::Integer, h::Integer, near::T, far::T) where {T}
    return projmatortho(zero(T), T(w), zero(T), T(h), near, far)
end

"""
    projmatortho(left::T, right::T, bottom::T, top::T, znear::T, zfar::T) where T

3D orthographic projection.
"""
function projmatortho(left::T, right::T, bottom::T, top::T, znear::T, zfar::T) where {T}
    if right == left || bottom == top || znear == zfar
        return Mat4{T}(I)
    else
        out = zeros(T, 4, 4)
        out[1, 1] = 2 / (right - left)
        out[2, 2] = 2 / (top - bottom)
        out[3, 3] = -2 / (zfar - znear)
        out[4, 1] = -(right + left) / (right - left)
        out[4, 2] = -(top + bottom) / (top - bottom)
        out[4, 3] = -(zfar + znear) / (zfar - znear)
        out[4, 4] = 1
        return Mat4{T}(out')
    end
end

function projmatortho(::Type{T}, left::Number, right::Number, bottom::Number, top::Number,
                      znear::Number, zfar::Number) where {T}
    return projmatortho(T(left), T(right), T(bottom), T(top), T(znear), T(zfar))
end

function Base.:(*)(q::Quaternions.Quaternion{T}, v::Vec{3,T}) where {T}
    t = T(2) * cross(Vec(q.v1, q.v2, q.v3), v)
    return v + q.s * t + cross(Vec(q.v1, q.v2, q.v3), t)
end
function Quaternions.qrotation(axis::Vec{3,T}, theta) where {T<:Real}
    u = normalize(axis)
    s = sin(theta / 2)
    return Quaternions.Quaternion{T}(cos(theta / 2), s * u[1], s * u[2], s * u[3], true)
end

mutable struct Pivot{T}
    origin      :: Vec{3,T}
    xaxis       :: Vec{3,T}
    yaxis       :: Vec{3,T}
    zaxis       :: Vec{3,T}
    rotation    :: Quaternions.Quaternion
    translation :: Vec{3,T}
    scale       :: Vec{3,T}
end

GeometryBasics.origin(p::Pivot) = p.origin

rotmat4(q::Quaternions.Quaternion{T}) where {T} = Mat4{T}(q)

function (::Type{M})(q::Quaternions.Quaternion) where {M<:Mat4}
    T = eltype(M)
    sx, sy, sz = 2q.s * q.v1, 2q.s * q.v2, 2q.s * q.v3
    xx, xy, xz = 2q.v1^2, 2q.v1 * q.v2, 2q.v1 * q.v3
    yy, yz, zz = 2q.v2^2, 2q.v2 * q.v3, 2q.v3^2
    T0, T1 = zero(T), one(T)
    return Mat{4}(T1 - (yy + zz), xy + sz, xz - sy, T0, xy - sz, T1 - (xx + zz), yz + sx,
                  T0, xz + sy, yz - sx, T1 - (xx + yy), T0, T0, T0, T0, T1)
end

function (::Type{M})(q::Quaternions.Quaternion) where {M<:Mat3}
    T = eltype(M)
    sx, sy, sz = 2q.s * q.v1, 2q.s * q.v2, 2q.s * q.v3
    xx, xy, xz = 2q.v1^2, 2q.v1 * q.v2, 2q.v1 * q.v3
    yy, yz, zz = 2q.v2^2, 2q.v2 * q.v3, 2q.v3^2
    T0, T1 = zero(T), one(T)
    return Mat{3}(T1 - (yy + zz), xy + sz, xz - sy, xy - sz, T1 - (xx + zz), yz + sx,
                  xz + sy, yz - sx, T1 - (xx + yy))
end
function transfmat(p::Pivot)
    return translmat(p.origin) * #go to origin
           rotmat4(p.rotation) * #apply rotation
           translmat(-p.origin) * # go back to origin
           translmat(p.translation) #apply translation
end

function transfmat(translation, scale)
    T = eltype(translation)
    T0, T1 = zero(T), one(T)
    return Mat{4}(scale[1], T0, T0, T0, T0, scale[2], T0, T0, T0, T0, scale[3], T0,
                  translation[1], translation[2], translation[3], T1)
end

function transfmat(translation, scale, rotation::Quaternions.Quaternion)
    T = eltype(translation)
    trans_scale = transfmat(translation, scale)
    rotation = Mat4f0(rotation)
    return trans_scale * rotation
end
function transfmat(translation, scale, rotation::Vec{3,T}, up = Vec{3,T}(0, 0, 1)) where {T}
    q = rotation(rotation, up)
    return transfmat(translation, scale, q)
end

#Calculate rotation between two vectors
function rotation(u::Vec{3,T}, v::Vec{3,T}) where {T}
    # It is important that the inputs are of equal length when
    # calculating the half-way vector.
    u, v = normalize(u), normalize(v)
    # Unfortunately, we have to check for when u == -v, as u + v
    # in this case will be (0, 0, 0), which cannot be normalized.
    if (u == -v)
        # 180 degree rotation around any orthogonal vector
        other = (abs(dot(u, Vec{3,T}(1, 0, 0))) < 1.0) ? Vec{3,T}(1, 0, 0) :
                Vec{3,T}(0, 1, 0)
        return Quaternions.qrotation(normalize(cross(u, other)), T(180))
    end
    half = normalize(u + v)
    return Quaternions.Quaternion(dot(u, half), cross(u, half)...)
end
