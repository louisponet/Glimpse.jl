import Base.Iterators: Cycle

import Base: ==

Component(id, ::Type{T}) where {T <: ComponentData}       = Component(id, GappedVector([T[]], Int[]))
SharedComponent(id, ::Type{T}) where {T <: ComponentData} = SharedComponent(id, GappedVector([Int[]], Int[]), T[])

data(component::AbstractComponent) = component.data

Base.length(::ComponentData)         = 1
Base.iterate(t::ComponentData)       = (t, nothing)

Base.isempty(c::AbstractComponent)   = isempty(c.data)
Base.empty!(c::AbstractComponent)    = empty!(c.data)

Base.length(c::AbstractComponent)    = length(c.data)
Base.size(c::AbstractComponent)      = size(c.data)
Base.lastindex(c::AbstractComponent) = lastindex(c.data)

Base.getindex(c::Component, i)       = getindex(c.data, i)
Base.getindex(c::SharedComponent, i) = c.shared[getindex(c.data, i)]

Base.setindex!(c::Component, v, i)   = setindex!(c.data, v, i)
overwrite!(c::Component, v, i)       = overwrite!(c.data, v, i)

function Base.setindex!(c::SharedComponent,v, i)
	id = findfirst(isequal(v), c.shared)
	if id == nothing
		id = length(c.shared) + 1
		push!(c.shared, v)
	end
	c.data[i] = id
end

valid_entities(c::AbstractComponent)     = Iterators.flatten(ranges(c.data))
valid_entities(cs::AbstractComponent...) = Iterators.flatten(ranges(data.(cs)...))
has_entity(c::AbstractComponent, entity) = has_index(c.data, entity)

function shared_entities(c::SharedComponent{T}, dat::T) where T
	ids = Int[]
	id = findfirst(x -> x == dat, c.shared)
	for i in eachindex(c.data)
		if c.data[i] == id
			push!(ids, i)
		end
	end
	return ids
end

==(c1::T, c2::T) where {T <: ComponentData} = all(getfield.((c1,), fieldnames(T)) .== getfield.((c2,), fieldnames(T)))
# DEFAULT COMPONENTS


abstract type ProgramKind end

struct RenderProgram{P <: ProgramKind} <: ComponentData
	program::Program
end
GLA.bind(p::RenderProgram) = bind(p.program)
GLA.set_uniform(p::RenderProgram, args...) = set_uniform(p.program, args...)

struct Vao{P <: ProgramKind} <: ComponentData
	vertexarray::VertexArray
	meshID     ::Int
end

# NON rendering Components
struct Dynamic <: ComponentData end
Base.@kwdef struct Spatial <: ComponentData
	position::Point3f0 = zero(Point3f0)
	velocity::Vec3f0   = zero(Vec3f0)
end

Base.@kwdef struct Shape <: ComponentData
	scale::Float32 = 1f0
end

Base.@kwdef struct ModelMat <: ComponentData
	modelmat::Mat4f0 = Eye4f0()
end

Base.@kwdef struct Material <: ComponentData
	specpow ::Float32 = 0.8f0
	specint ::Float32 = 0.8f0
end

Base.@kwdef struct PointLight <: ComponentData
    position::Point3f0 = Point3f0(200)
    diffuse ::Float32  = 0.5f0
    specular::Float32  = 0.5f0
    ambient ::Float32  = 0.5f0
end

struct DirectionLight <: ComponentData
	direction::Vec3f0
    diffuse  ::Float32
    specular ::Float32
    ambient  ::Float32
end

mutable struct Camera3D <: ComponentData
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

# Meshing and the like
struct Mesh <: ComponentData
	mesh
end

abstract type Color <: ComponentData end

# one color, will be put as a uniform in the shader
struct UniformColor <: Color 
	color::RGBAf0
end

# vector of colors, either supplied manually or filled in by mesher
struct BufferColor <: Color
	color::Vector{RGBAf0}
end
	
# color function, mesher uses it to throw in points and get out colors
struct FuncColor{F} <: Color 
	color::F
end

# Cycle, mesher uses it to iterate over together with points
struct CycledColor <: Color
	color::Cycle{Union{RGBAf0, Vector{RGBAf0}}}
end

struct Grid <: ComponentData
	points::Array{Point3f0, 3}
end

abstract type Geometry <: ComponentData end

struct PolygonGeometry <: Geometry #spheres and the like
	geometry 
end

struct FileGeometry <: Geometry #.obj files
	geometry::String 
end

struct FuncGeometry <: Geometry
	geometry::Function
	iso_value::Float64
end

struct VectorGeometry <: Geometry
	geometry::Vector{Point3f0}
end
