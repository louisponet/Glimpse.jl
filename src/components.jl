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

struct UploadData
	isinstanced ::Bool
	renderpasses::Vector{Symbol}
end
UploadComponent(id) = Component{:render}(id, RenderData[])

struct ChildData
	child_id::Int
end
ChildComponent(id) = Component{:child}(id, ChildData[])

struct ParentData
	parent_id::Int
end
ParentComponent(id) = Component{:parent}(id, ParentData[])

struct RenderData
	is_instanced::Bool
	is_visible  ::Bool
	renderpasses::Vector{Symbol}
	is_uploaded ::Vector{Bool}      # Bool is whether it's uploaded or not
	vertexarrays::Vector{VertexArray}
end
RenderComponent(id) = Component{:render}(id, RenderData[])

is_instanced(data::RenderData) = data.is_instanced

has_pass(data::RenderData, pass::RenderPass{name}) where name = in(name, data.renderpasses)
pass_id(data::RenderData, pass::RenderPass{name})  where name = findfirst(isequal(name), data.renderpasses) 
is_uploaded(data::RenderData, pass::RenderPass)               = data.is_uploaded[pass_id(data, pass)]
set_uploaded(data::RenderData, pass::RenderPass, b::Bool)     = data.is_uploaded[pass_id(data, pass)] = b
renderpass_vao(data::RenderData, pass::RenderPass)            = data.vertexarrays[pass_id(data, pass)]


struct MaterialData
	specpow ::Float32
	specint ::Float32
end

MaterialComponent(id) = Component{:material}(id, MaterialData[])

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


