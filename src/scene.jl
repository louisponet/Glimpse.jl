import GLAbstraction: free!

mutable struct Scene
    name::Symbol
    renderables::Vector{<:Renderable}
    camera::Camera
end

function Scene(name::Symbol, renderables::Vector{<:Renderable})
    dim = 2
    for r in renderables
        dim = eltype(r)[1] > dim ? eltype(r)[1] : dim
    end
    area = Area(0, 0, standard_screen_resolution()...)
    if dim == 2
        camera = Camera{pixel}(Vec2f0(0), Vec2f0(0,1), Vec2f0(-1,0), area)
    elseif dim == 3
        camera = Camera{perspective}(Vec3f0(0,-1,0), Vec3f0(0), Vec3f0(0,0,1), Vec3f0(-1,0,0))
    end
    return Scene(name, renderables, camera)
end


function free!(sc::Scene)
    for r in sc.renderables
        free!(r)
    end
end
