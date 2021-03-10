import Base.Iterators: Cycle

@component struct DioEntity end

#TODO get rid of this in favor of a correct iterator
function shared_entities(c::SharedComponent{T}, dat::T) where T
	ids = Int[]
	id = findfirst(x -> x == dat, c.shared)
	return findall(x -> x == id, data(c))
end

# DEFAULT COMPONENTS
abstract type Vao <: ComponentData end

macro vao(name)
    esc(quote
        @component @with_kw mutable struct $name <: Vao
        	vertexarray::VertexArray
        	visible    ::Bool = true
    	end
    	$name(v::VertexArray) = $name(vertexarray=v)
	end)
end

macro instanced_vao(name)
    esc(quote
        @shared_component @with_kw mutable struct $name <: Vao
        	vertexarray::VertexArray
        	visible    ::Bool = true
    	end
    	$name(v::VertexArray) = $name(vertexarray=v)
	end)
end

Base.length(vao::Vao) = length(vao.vertexarray)
GLA.bind(vao::Vao) = GLA.bind(vao.vertexarray)

GLA.draw(vao::Vao) = GLA.draw(vao.vertexarray)

GLA.upload!(vao::Vao; kwargs...) = GLA.upload!(vao.vertexarray; kwargs...) 

# NON rendering Components
@component struct Dynamic  end
@component @with_kw struct Spatial 
	position::Point3f0 = zero(Point3f0)
	velocity::Vec3f0   = zero(Vec3f0)
end

Base.:(+)(s1::Spatial, s2::Spatial) = Spatial(s1.position + s2.position, s1.velocity + s2.velocity)
Base.:(-)(s1::Spatial, s2::Spatial) = Spatial(s1.position - s2.position, s1.velocity - s2.velocity)


@component struct Rotation 
	q::Quaternions.Quaternion{Float32}
end
Rotation(axis::Vec, angle::Number) = Rotation(Quaternions.qrotation(axis, angle))
Rotation(axis1::Vec, axis2::Vec) = Rotation(rotation(axis1, axis2))

Base.:(*)(r1::Rotation, r2::Rotation) = Rotation(r1.q * r2.q)

Quaternions.angleaxis(r::Rotation) = Quaternions.angleaxis(r.q)
Quaternions.axis(r::Rotation)      = Quaternions.axis(r.q)
Quaternions.angle(r::Rotation)     = Quaternions.angle(r.q)

GeometryBasics.direction(r::Rotation) = r.q * Z_AXIS

@component @with_kw struct Shape 
	scale::Vec3f0 = Vec3f0(1f0)
end
Shape(f::Real) = Shape(Vec3f0(f))
Base.length(::Type{Shape}) = 3
Base.eltype(::Type{Shape}) = Float32

@component @with_kw struct ModelMat 
	modelmat::Mat4f0 = Eye4f0()
end
Base.length(::Type{ModelMat}) = 16
Base.eltype(::Type{ModelMat}) = Float32

@component @with_kw struct Material 
	specpow ::Float32 = 0.8f0
	specint ::Float32 = 0.8f0
end
Base.eltype(::Type{Material}) = Float32
Base.length(::Type{Material}) = 2

@component @with_kw struct PointLight 
    diffuse ::Float32  = 0.5f0
    specular::Float32  = 0.5f0
    ambient ::Float32  = 0.5f0
end
Base.length(::Type{PointLight}) = 3
Base.eltype(::Type{PointLight}) = Float32

@component struct DirectionLight 
	direction::Vec3f0
    diffuse  ::Float32
    specular ::Float32
    ambient  ::Float32
end

# Meshing and the like
@shared_component struct Mesh 
	mesh
end

@component struct Alpha
    α::Float32
end
Base.length(::Type{Alpha}) = 1
Base.eltype(::Type{Alpha}) = Float32


abstract type Color <: ComponentData end

# one color, will be put as a uniform in the shader
@component @with_kw struct UniformColor <: Color 
	color::RGBf0 = DEFAULT_COLOR 
end
UniformColor(x,y,z) = UniformColor(RGBf0(x, y, z))
Base.length(::Type{UniformColor}) = 3
Base.eltype(::Type{UniformColor}) = Float32

# vector of colors, either supplied manually or filled in by mesher
@component struct BufferColor <: Color
	color::Vector{RGBf0}
end
	
# color function, mesher uses it to throw in points and get out colors
#TODO super slow
@component struct FunctionColor <: Color 
	color::Function
end

@component struct DensityColor <: Color 
	color::Array{RGBf0, 3}
end

# Cycle, mesher uses it to iterate over together with points
@component struct CycledColor <: Color
	color::Cycle{Union{RGBAf0, Vector{RGBAf0}}}
end

@component struct IDColor <: Color
    color::RGBf0
end

@shared_component struct Grid 
	points::Array{Point3f0, 3}
end

abstract type Geometry <: ComponentData end

@component struct PolygonGeometry <: Geometry #spheres and the like
	geometry 
end

@component struct FileGeometry <: Geometry #.obj files
	geometry::String 
end

@component struct FunctionGeometry <: Geometry
	geometry::Function
	iso     ::Float32
end

@component struct DensityGeometry <: Geometry
	geometry::Array{Float32, 3}
	iso     ::Float32
end

@component struct VectorGeometry <: Geometry
	geometry::Vector{Point3f0}
end

@component struct LineGeometry <: Geometry
    points::Vector{Point3f0}
    function LineGeometry(points::Vector{Point3f0})
        if length(points) < 4
            insert!(points, 1, points[2] + 1.001*(points[1] - points[2]))
        end
        if length(points) < 4
            push!(points, points[end-1] + 1.001*(points[end] - points[end-1]))
        end
        return new(points)
    end
end

@component @with_kw struct LineOptions 
	thickness::Float32 = 2.0f0
	miter    ::Float32 = 0.6f0
end

@component @with_kw struct Text 
	str      ::String  = "test"
	font_size::Float64 = 20
	font     = default_font()
	align    ::Tuple{Symbol, Symbol} = (:bottom, :right)
	offset   ::Vec3f0= zero(Vec3f0)
end
