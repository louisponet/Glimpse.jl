import GLAbstraction: free!

mutable struct Scene
    name::Symbol
    renderables::Vector{<:Renderable}
    camera::Camera
end
Scene() = Scene(:Glimpse, Renderable[], Camera{perspective}())
function Scene(name::Symbol, renderables::Vector{<:Renderable})
    dim = 2
    for r in renderables
        dim = eltype(r)[1] > dim ? eltype(r)[1] : dim
    end
    area = Area(0, 0, standard_screen_resolution()...)
    if dim == 2
        camera = Camera{pixel}()
    elseif dim == 3
        camera = Camera{perspective}()
    end
    return Scene(name, renderables, camera)
end

function free!(sc::Scene)
    for r in sc.renderables
        free!(r)
    end
    return sc
end

"""
Adds a renderable to the scene. If the copy flag is true the renderable will be deepcopied.
The id of the renderable will be set to it's index inside the renderables list of the Scene.
"""
function add!(sc::Scene, renderable::Renderable, _copy=false)
    rend = _copy ? deepcopy(renderable) : renderable
    rend.id = length(sc.renderables) + 1
    push!(sc.renderables, rend)
end

function set!(sc::Scene, camera::Camera)
    sc.camera = camera
end

projmat(sc::Scene) = sc.camera.proj
viewmat(sc::Scene) = sc.camera.view
projviewmat(sc::Scene) = sc.camera.projview
