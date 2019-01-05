abstract type Light{T} end

mutable struct PointLight{T <: AbstractFloat} <: Light{T}
    position::Vec3{T}
    diffuse ::T
    specular::T
    ambient ::T
    color   ::RGB{T}
end

PointLight() = PointLight{f32}(Vec3f0(0,0,20), 0.8f0, 1.0f0, 0.2f0, RGB{f32}(1,1,1))

#Direction always has to be normalized!
mutable struct DirectionLight{T <: AbstractFloat} <: Light{T}
    direction::Vec3{T}
    diffuse ::T
    specular::T
    ambient ::T
    color   ::RGB{T}
end

"Darkens the light by the percentage"
function darken!(light::Light{T}, percentage) where T
    light.diffuse  *= convert(T, percentage)
    light.specular *= convert(T, percentage)
    light.ambient  *= convert(T, percentage)
end
