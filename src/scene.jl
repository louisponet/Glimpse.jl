import GLAbstraction: free!

#TODO so what should ultimately happen is that we allow for multiple cameras,
#     which would result in multiple canvasses inside one big screen.
mutable struct Scene
    name::Symbol
    renderables::Vector{<:Renderable}
    camera::Camera
    lights::Vector{<:Light}
end
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
    return Scene(name, renderables, camera, Light[])
end
Scene(; kwargs...) = Scene(:Glimpse, Renderable[], Camera{perspective}(; kwargs...), Light[])

function free!(sc::Scene)
    for r in sc.renderables
        free!(r)
    end
    return sc
end

"""
Adds a renderable to the scene. If the copy flag is true the renderable will be deepcopied.
The index of the renderable will be set to it's index inside the renderables list of the Scene.
"""
function add!(sc::Scene, renderable::Renderable, _copy=false)
    rend = _copy ? deepcopy(renderable) : renderable
    rend.index = length(sc.renderables) + 1
    push!(sc.renderables, rend)
end

"""
Adds a renderable to the scene. If the copy flag is true the renderable will be deepcopied.
The index of the renderable will be set to it's index inside the renderables list of the Scene.
"""
add!(sc::Scene, light::Light) = push!(sc.lights, light)

"""
Clears all the renderables from a scene.
"""
function Base.empty!(sc::Scene)
    for rb in sc.renderables
        free!(rb)
    end
    empty!(sc.renderables)
    return sc
end

function set!(sc::Scene, camera::Camera)
    sc.camera = camera
end

function center!(sc::Scene)
    center = zero(Vec3f0)
    for rb in sc.renderables
        modelmat = get(rb.uniforms, :modelmat, Eye4f0())
        center += Vec3f0((modelmat * Vec4f0(0,0,0,1))[1:3]...)
    end
    center /= length(sc.renderables)
    sc.camera.lookat = center
    # sc.camera.eyepos = Vec3f0((translmat(center) * Vec4f0(sc.camera.eyepos...,1))[1:3]...)
    update!(sc.camera)
end

projmat(sc::Scene) = sc.camera.proj
viewmat(sc::Scene) = sc.camera.view
projviewmat(sc::Scene) = sc.camera.projview
