import GeometryTypes: SVector, Mat
@enum CamKind pixel orthographic perspective

function projmat(x::CamKind, area::Area, near::T, far::T, fov::T=zero(T)) where T
    if x == pixel
        return eye(T,4)
    elseif x == orthographic
        return projmatortho(area, near, far)
    else
        return projmatpersp(area, fov, near, far)
    end
end


mutable struct Camera{Kind, Dim, T}
    eyepos ::SVector{Dim, T}
    up     ::SVector{Dim, T}
    left   ::SVector{Dim, T}
    lookat ::SVector{Dim, T}
    fov    ::T
    near   ::T
    far    ::T
    view   ::Mat4{T}
    projection        ::Mat4{T}
    projectionview    ::Mat4{T}
    rotation_speed    ::T
    translation_speed ::T
    function (::Type{Camera{Kind}})(eyepos::Vec{Dim, T}, up, left, lookat, fov, near, far, viewm, projm, projview, rotation_speed, translation_speed) where {Kind, Dim, T} 
        temp = new{Kind, Dim, T}()
        temp.eyepos = eyepos
        return temp
    end
end 

# function Camera{Kind}(eyepos::SVector{Dim, T}, lookat::SVector{Dim,T}, up::SVector{Dim, T}, left::SVector{Dim, T}; 
#                 fov  = T(41.0),
#                 near = T(0.0),
#                 far  = T(100.),
#                 rotation_speed    = T(1.0),
#                 translation_speed = T(1.0)) where {Kind, Dim, T}
#     println("ping") 
#     projm = projmat(Kind, area, near, far, fov)
#     viewm = lookatmat(eyepos, lookat, up)
#     return Camera(eyepos, up, left, lookat, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed)
# end
function Camera{Kind}(eyepos, lookat, up, left,area; 
                fov  = 41.0f0,
                near = 0.0f0,
                far  = 100.0f0,
                rotation_speed    = 1.0f0,
                translation_speed = 1.0f0) where Kind
    projm = projmat(Kind, area, near, far, fov)
    viewm = lookatmat(eyepos, lookat, up)
    return Camera{Kind}(eyepos, up, left, lookat, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed)
end


