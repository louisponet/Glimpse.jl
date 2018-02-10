abstract type Light{T} end

struct PointLight{T <: AbstractFloat} <: Light{T}
    position::Vec3{T}
    diffuse ::T
    ambient ::T
    color   ::Vec3{T}
end
PointLight() = PointLight{f32}(Vec3f0(0,0,20), 0.8f0, 0.2f0, Vec3{f32}(1,1,1))
#Direction always has to be normalized!
struct DirectionLight{T <: AbstractFloat} <: Light{T}
    direction::Vec3{T}
    diffuse ::T
    specular::T
    ambient ::T
    color   ::RGB{T}
end
