mutable struct Scene
    name::Symbol
    renderables::Vector{Renderable}
    camera::Camera
end
