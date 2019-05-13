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

valid_entities(c::AbstractComponent)     = collect(Iterators.flatten(ranges(c.data)))
valid_entities(cs::AbstractComponent...) = collect(Iterators.flatten(ranges(data.(cs)...)))
has_entity(c::AbstractComponent, entity) = has_index(c.data, entity)
Base.pointer(c::AbstractComponent, id::Int) = pointer(c.data, id)

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

struct ProgramTag{P <: ProgramKind} <: ComponentData end

@with_kw struct Vao{P <: ProgramKind} <: ComponentData
	vertexarray::VertexArray
	visible    ::Bool = true
end
programkind(::Vao{P}) where {P} = P

GLA.bind(vao::Vao) = GLA.bind(vao.vertexarray)

GLA.draw(vao::Vao) = GLA.draw(vao.vertexarray)

# NON rendering Components
struct Dynamic <: ComponentData end
@with_kw struct Spatial <: ComponentData
	position::Point3f0 = zero(Point3f0)
	velocity::Vec3f0   = zero(Vec3f0)
end

@with_kw struct Shape <: ComponentData
	scale::Float32 = 1f0
end

@with_kw struct ModelMat <: ComponentData
	modelmat::Mat4f0 = Eye4f0()
end

@with_kw struct Material <: ComponentData
	specpow ::Float32 = 0.8f0
	specint ::Float32 = 0.8f0
end

@with_kw struct PointLight <: ComponentData
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

const X_AXIS = Vec3f0(1.0f0, 0.0  , 0.0)
const Y_AXIS = Vec3f0(0.0,   1.0f0, 0.0)
const Z_AXIS = Vec3f0(0.0,   0.0  , 1.0f0)

@with_kw struct Camera3D <: ComponentData
    lookat ::Vec3f0  = zero(Vec3f0)
    up     ::Vec3f0  = Z_AXIS 
    right  ::Vec3f0  = X_AXIS 
    fov    ::Float32 = 42f0
    near   ::Float32 = 0.1f0
    far    ::Float32 = 3000f0
    view   ::Mat4f0
    proj        ::Mat4f0
    projview    ::Mat4f0
    rotation_speed    ::Float32 = 0.001f0
    translation_speed ::Float32 = 0.5f0
    mouse_pos         ::Vec2f0  = zero(Vec2f0)
    scroll_dx         ::Float32 = 0.0f0
    scroll_dy         ::Float32 = 0.0f0
end

function Camera3D(width_pixels::Integer, height_pixels::Integer; eyepos = -10*Y_AXIS,
													     lookat = zero(Vec3f0),
                                                         up     = Z_AXIS,
                                                         right  = X_AXIS,
                                                         near   = 0.1f0,
                                                         far    = 3000f0,
                                                         fov    = 42f0)
    up    = normalizeperp(lookat - eyepos, up)
    right = normalize(cross(lookat - eyepos, up))

    viewm = lookatmat(eyepos, lookat, up)
    projm = projmatpersp(width_pixels, height_pixels, near, far, fov)
    return Camera3D(lookat=lookat, up=up, right=right, fov=fov, near=near, far=far, view=viewm, proj=projm, projview=projm * viewm) 
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
struct FunctionColor{F} <: Color 
	color::F
end

struct DensityColor <: Color 
	color::Array{RGBAf0, 3}
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

struct FunctionGeometry <: Geometry
	geometry::Function
	iso     ::Float32
end

struct DensityGeometry <: Geometry
	geometry::Array{Float32, 3}
	iso     ::Float32
end

struct VectorGeometry <: Geometry
	geometry::Vector{Point3f0}
end

struct Line <: ComponentData
	thickness::Float32
	miter    ::Float32
end

@with_kw struct Text <: ComponentData
	str      ::String = "test"
	font_size::Int    = 1
	font     = AP.defaultfont()
	align    ::Symbol = :right
end
	
