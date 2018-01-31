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
        new{Kind, Dim, T}(eyepos, up, left, lookat, fov, near, far, viewm, projm, projview, rotation_speed, translation_speed)
    end
end 

function (::Type{Camera{perspective}})(eyepos, lookat, up, left,area; 
                fov  = 41.0f0,
                near = 0.0f0,
                far  = 100.0f0,
                rotation_speed    = 1.0f0,
                translation_speed = 1.0f0)
    projm = projmat(perspective, area, near, far, fov)
    viewm = lookatmat(eyepos, lookat, up)
    return Camera{perspective}(eyepos, up, left, lookat, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed)
end

(::Type{Camera{perspective}})() = Camera{perspective}(Vec3f0(0,-1,0), Vec3f0(0), Vec3f0(0,0,1), Vec3f0(-1,0,0), current_context().area)


(::Type{Camera{pixel}})(center::Vec{2, Float32}, up, left, area) where pixel = 
    Camera{pixel}(center, up, left, center, 0f0, 0f0, 0f0, Eye4f0(), Eye4f0(), Eye4f0(), 0f0, 0f0)
(::Type{Camera{pixel}})() where pixel = Camera{pixel}(Vec2f0(0), Vec2f0(0,1), Vec2f0(-1,0), area)


