data(component::Component) = component.data
name(component::Component{n}) where n = n

Component{name}(id, data::Vector{T}) where {name, T} = Component{name, T}(id, data)

struct SpatialData
	position::Vec3f0
	velocity::Vec3f0
end
SpatialComponent(id) = Component{:spatial}(id, SpatialData[]) 

struct TypeData
	typ::Type
end
TypeComponent(id) = Component{:type}(id, TypeData[])

struct GeometryData{M <: AbstractGlimpseMesh}
	mesh::M
end
GeometryComponent(id) = Component{:geometry}(id, GeometryData[])


mutable struct RenderData
	is_instanced::Bool
	is_visible  ::Bool
	vertexarray ::VertexArray
end

DefaultRenderComponent(id)      = Component{:default_render}(id, RenderData[])
DepthPeelingRenderComponent(id) = Component{:depth_peeling_render}(id, RenderData[])

is_instanced(data::RenderData) = data.is_instanced
is_uploaded(data::RenderData) = !GLA.is_null(data.vertexarray)

struct MaterialData
	specpow ::Float32
	specint ::Float32
	color   ::RGBf0
end

MaterialComponent(id) = Component{:material}(id, MaterialData[])

struct ShapeData
	scale::Float32
end

ShapeComponent(id) = Component{:shape}(id, ShapeData[])

struct PointLightData
    position::Vec3f0
    diffuse ::Float32
    specular::Float32
    ambient ::Float32
    color   ::RGBf0
end

PointLightComponent(id) = Component{:point_light}(id, PointLightData[])

struct DirectionLightData
	direction::Vec3f0
    diffuse  ::Float32
    specular ::Float32
    ambient  ::Float32
    color    ::RGBf0	
end

DirectionLightComponent(id) = Component{:direction_light}(id, PointLightData[])

mutable struct CameraData3D
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

CameraComponent3D(id) = Component{:camera3d}(id, CameraData3D[])
# const RenderPassData = NamedTuple{(:programs, :targets, :renderable_ids, :vertexarrays,  


