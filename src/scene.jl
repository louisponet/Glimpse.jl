import GLAbstraction: free!

mutable struct Scene
    name::Symbol
    renderables::Vector{Renderable}
    camera::Camera
end

function free!(sc::Scene)
    for r in sc.renderables
        free!(r)
    end
end
