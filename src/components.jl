data(component::Component) = component.data


# Component(id, data::Vector{T}) where {T<:ComponentData} = Component{T}(id, data)

struct Spatial <: ComponentData
	position::Vec3f0
	velocity::Vec3f0
end
SpatialComponent(id) = Component(id, Spatial[]) 

struct Geometry <: ComponentData
	mesh
end
GeometryComponent(id) = Component(id, Geometry[])


mutable struct Render{RP <: RenderPassKind} <: ComponentData
	is_instanced::Bool
	is_visible  ::Bool
	vertexarray ::VertexArray
end

DefaultRenderComponent(id)      = Component(id, Render{DefaultPass}[])
DepthPeelingRenderComponent(id) = Component(id, Render{DepthPeelingPass}[])

is_instanced(data::Render) = data.is_instanced
is_uploaded(data::Render)  = !GLA.is_null(data.vertexarray)
kind(::Type{Render{Kind}}) where Kind = Kind

struct Material <: ComponentData
	specpow ::Float32
	specint ::Float32
	color   ::RGBf0
end

MaterialComponent(id) = Component(id, Material[])

struct Shape <: ComponentData
	scale::Float32
end

ShapeComponent(id) = Component(id, Shape[])

struct PointLight <: ComponentData
    position::Vec3f0
    diffuse ::Float32
    specular::Float32
    ambient ::Float32
    color   ::RGBf0
end

PointLightComponent(id) = Component(id, PointLight[])

struct DirectionLight <: ComponentData
	direction::Vec3f0
    diffuse  ::Float32
    specular ::Float32
    ambient  ::Float32
    color    ::RGBf0	
end

DirectionLightComponent(id) = Component(id, PointLight[])

mutable struct Camera3D <: ComponentData
    eyepos ::Vec3f0
    lookat ::Vec3f0
    up     ::Vec3f0
    right  ::Vec3f0
    fov    ::Float32
    near   ::Float32
    far    ::Float32
    view   ::Mat4f0
    proj        ::Mat4f0
    projview    ::Mat4f0
    rotation_speed    ::Float32
    translation_speed ::Float32
    mouse_pos         ::Vec2f0
    scroll_dx         ::Float32
    scroll_dy         ::Float32
end

CameraComponent3D(id) = Component(id, Camera3D[])
# const RenderPass = NamedTuple{(:programs, :targets, :renderable_ids, :vertexarrays,  


