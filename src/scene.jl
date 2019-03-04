import GLAbstraction: free!


#TODO: change such that there are no components until needed?
StandardSceneComponents() = [GeometryComponent(1),
		  					 DefaultRenderComponent(2),
		  					 MaterialComponent(3),
		  					 ShapeComponent(4),
						     SpatialComponent(5),
						     PointLightComponent(6),
						     CameraComponent3D(7)]

Scene(name::Symbol) = Scene(name, Entity[], StandardSceneComponents())

Scene(; kwargs...) = Scene(:Glimpse)

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

projmat(sc::Scene)     = sc.camera.proj
viewmat(sc::Scene)     = sc.camera.view
projviewmat(sc::Scene) = sc.camera.projview

"Darken all the lights in the scene by a certain amount"
darken!(scene::Scene, percentage)  = darken!.(scene.lights, percentage)
lighten!(scene::Scene, percentage) = lighten!.(scene.lights, percentage)

component(scene::Scene, n::Symbol) = getfirst(x -> name(x) == n, scene.components)
# component_id(scene::Scene, name::Symbol) = findfirst( x -> x.name == name, scene.components)
new_entity_data_id(component::Component) = length(component.data) + 1

new_component!(scene::Scene, component::Component) = push!(scene.components, component)

#TODO handle freeing and reusing stuff
function add_to_components!(datas, components)
	data_ids  = Int[]
	for (data, comp) in zip(datas, components)
		data_id    = new_entity_data_id(comp)
		push!(data_ids, data_id)
		push!(comp.data, data)
	end
	return data_ids
end

function new_entity!(scene::Scene; name_data...)
	entity_id  = length(scene.entities) + 1

	names      = keys(name_data)
	components = component.((scene, ), names)
	@assert !any(components .== nothing) "Error, $(names[findall(isequal(nothing), components)]) is not present in the scene yet. TODO add this automatically"
	data_ids   = add_to_components!(values(name_data), components)
	
	push!(scene.entities, Entity(entity_id, NamedTuple{(names...,)}(data_ids)))
end

function add_entity_components!(scene::Scene, entity_id::Int; name_data...)
	entity = getfirst(x->x.id == entity_id, scene.entities)
	if entity == nothing
		error("entity id $entity_id doesn't exist")
	end

	names      = keys(name_data)
	components = component.((scene, ), names)
	data_ids   = add_to_components!(values(name_data), components)

	append!(data_ids, values(entity.data_ids))
	allnames = (keys(entity.data_ids)..., names...)
	scene.entities[entity_id] = Entity(entity_id, NamedTuple{allnames}(data_ids))
end


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
