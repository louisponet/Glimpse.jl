import GLAbstraction: free!

#TODO so what should ultimately happen is that we allow for multiple cameras,
#     which would result in multiple canvasses inside one big screen.
#TODO: finalizer free!
function Scene(name::Symbol, renderables::MeshRenderable...)
    dim = 2
    for r in renderables
        dim = eltypes(meshtype(r))[2] > dim ? eltypes(meshtype(r))[2] : dim
    end
    area = Area(0, 0, standard_screen_resolution()...)
    if dim == 2
        camera = Camera{pixel}()
    elseif dim == 3
        camera = Camera{perspective}()
    end
    return Scene(name, [renderables...], camera, Light[])
end
Scene(; kwargs...) = Scene(:Glimpse, MeshRenderable[], Camera{perspective}(; kwargs...), Light[])
renderables(scene::Scene) = scene.renderables

"""
Adds a renderable to the scene. If the copy flag is true the renderable will be deepcopied.
The index of the renderable will be set to it's index inside the renderables list of the Scene.
"""
function add!(sc::Scene, renderable::MeshRenderable, _copy=false)
    rend = _copy ? deepcopy(renderable) : renderable
    push!(sc.renderables, rend)
end

"Adds a light to the scene. "
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
    update!(sc.camera)
end

projmat(sc::Scene) = sc.camera.proj
viewmat(sc::Scene) = sc.camera.view
projviewmat(sc::Scene) = sc.camera.projview

renderable(sc::Scene, name::String; fuzzy=true) =
    fuzzy ? getfirst(x -> occursin(name, x.name), sc.renderables) : getfirst(x -> x.name == name, sc.renderables)
renderables(sc::Scene, name::String; fuzzy=true) =
    fuzzy ? filter(x -> occursin(name, x.name), sc.renderables) : filter(x -> x.name == name, sc.renderables)

set_uniforms!(sc::Scene, name::String, uniforms::Pair{Symbol, Any}...; fuzzy=true) =
    set_uniforms!.(renderables(sc, name; fuzzy=fuzzy), uniforms...)

"Darken all the lights in the scene by a certain amount"
darken!(scene::Scene, percentage)  = darken!.(scene.lights, percentage)
lighten!(scene::Scene, percentage) = lighten!.(scene.lights, percentage)
