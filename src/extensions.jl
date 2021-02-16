import GLAbstraction: FrameBuffer, VertexArray, Buffer, Program, BufferAttachmentInfo
import GLAbstraction: textureformat_from_type_sym, getfirst, gluniform, clear!

#----------------GLAbstraction-------------------------#
default_framebuffer(fb_size) = FrameBuffer(fb_size, DepthStencil{GLAbstraction.Float24, N0f8}, RGBA{N0f8}, Vec{2, GLushort}, RGBA{N0f8})

clear!(fbo::FrameBuffer, color::RGBA) = clear!(fbo, (color.r, color.g, color.b, color.alpha))

const fullscreen_pos = [Vec3f0(-1, 1, 0), Vec3f0(-1, -1, 0),
                        Vec3f0(1, 1, 0) , Vec3f0(1, -1, 0)]

const fullscreen_uv = [Vec2f0(0, 1), Vec2f0(0, 0),
                       Vec2f0(1, 1), Vec2f0(1, 0)]


#REVIEW: not used
function glenum2julia(x::UInt32)
    x == GL_FLOAT      && return Float32
    x == GL_FLOAT_VEC3 && return Vec3f0
    x == GL_FLOAT_VEC4 && return Vec4f0
    x == GL_FLOAT_MAT2 && return Mat2f0
    x == GL_FLOAT_MAT3 && return Mat3f0
    x == GL_FLOAT_MAT4 && return Mat4f0

    x == GL_DOUBLE      && return f64
    x == GL_DOUBLE_VEC3 && return Vec3{f64}
    x == GL_DOUBLE_VEC4 && return Vec4{f64}
    x == GL_DOUBLE_MAT2 && return Mat2{f64}
    x == GL_DOUBLE_MAT3 && return Mat3{f64}
    x == GL_DOUBLE_MAT4 && return Mat4{f64}

    x == GL_INT       && return i32
    x == GL_INT_VEC2  && return Vec2{i32}
    x == GL_INT_VEC3  && return Vec3{i32}
    x == GL_INT_VEC4  && return Vec4{i32}

    x == GL_UNSIGNED_INT        && return u32
    x == GL_UNSIGNED_INT_VEC2   && return Vec2{u32}
    x == GL_UNSIGNED_INT_VEC3   && return Vec3{u32}
    x == GL_UNSIGNED_INT_VEC4   && return Vec4{u32}
end

function mergepop!(d1, d2)
    t = SymAnyDict()

    d = isempty(d2) ? SymAnyDict() : Dict(d2)
    for (key, val) in d1
        t[key] = pop!(d, key, val)
    end
    d2 = [d...]
    return t
end

Base.ndims(::Type{<:Colorant}) = 1
Base.size(::Type{<:Number}) = 1

#this stuff is here because of world age stuff I think
function gluniform(location::Integer, x::Mat4{Float32})
    glUniformMatrix4fv(location, 1, GL_FALSE, reinterpret(Float32,[x]))
end

function uniformfunc(typ::DataType, dims::Tuple{Int})
    Symbol(string("glUniform", first(dims), GLAbstraction.opengl_postfix(typ)))
end

function uniformfunc(typ::DataType, dims::Tuple{Int, Int})
    M, N = dims
    Symbol(string("glUniformMatrix", M == N ? "$M" : "$(M)x$(N)", opengl_postfix(typ)))
end

function gluniform(location::Integer, x::FSA) where FSA
    GLAbstraction.glasserteltype(FSA)
    xref = [x]
    gluniform(location, xref)
end


@generated function gluniform(location::Integer, x::Vector{FSA}) where FSA
    GLAbstraction.glasserteltype(eltype(FSA))
    func = uniformfunc(eltype(FSA), size(FSA))
    callexpr = if ndims(FSA) == 2
        :($func(location, length(x), GL_FALSE, xref))
    else
        :($func(location, length(x), xref))
    end
    quote
        xref = reinterpret(eltype(FSA), x)
        $callexpr
    end
end

gluniform(location::Integer, x::Int) = gluniform(location, GLint(x))
gluniform(location::Integer, x::UInt) = gluniform(location, GLuint(x))
gluniform(location::Integer, x::AbstractFloat) = gluniform(location, GLfloat(x))

#----------------- Composite OpenGL Calls -------------#
const none = !any

function glEnableDepth(f::Function)
    glEnable(GL_DEPTH_TEST)
    if f == all
        glDepthFunc(GL_ALWAYS)
    elseif f == none
        glDepthFunc(GL_NEVER)
    elseif f == <
        glDepthFunc(GL_LESS)
    elseif f == <=
        glDepthFunc(GL_LEQUAL)
    elseif f == >
        glDepthFunc(GL_GREATER)
    elseif f == >=
        glDepthFunc(GL_GEQUAL)
    elseif f == ==
        glDepthFunc(GL_EQUAL)
    elseif f == !=
        glDepthFunc(GL_NOTEQUAL)
    else
        @error "Function $f has no OpenGL DepthFunc equivalent."
    end
end

glDisableDepth() = glDisable(GL_DEPTH_TEST)

function glEnableCullFace(s::Symbol)
    glEnable(GL_CULL_FACE)
    if s == :front
        glCullFace(GL_FRONT)
    elseif s == :back
        glCullFace(GL_BACK)
    elseif s == :front_back
        glCullFace(GL_FRONT_AND_BACK)
    else
        @error "Symbol $s has no OpenGL CullFace equivalent."
    end
end

glDisableCullFace() = glDisable(GL_CULL_FACE)

function generate_buffers(program::Program, divisor::GLint; name_buffers...)
	buflen  = 0
    buffers = BufferAttachmentInfo[]
    for (name, val) in pairs(name_buffers)
        loc = attribute_location(program, name)
        if loc != INVALID_ATTRIBUTE
	        buflen = buflen == 0 ? length(val) : buflen 
            vallen = length(val)
            if vallen == buflen
                push!(buffers, BufferAttachmentInfo(name, loc, Buffer(val, usage=GL_DYNAMIC_DRAW), divisor))
            elseif !isa(val, Vector)
                push!(buffers, BufferAttachmentInfo(name, loc, Buffer(fill(val, buflen), usage=GL_DYNAMIC_DRAW), divisor))
            end
        end
    end
    return buffers
end
## StaticArrays
const Area            = Rect2D
const X_AXIS          = Vec3f0(1.0f0, 0.0  , 0.0)
const Y_AXIS          = Vec3f0(0.0,   1.0f0, 0.0)
const Z_AXIS          = Vec3f0(0.0,   0.0  , 1.0f0)

GeometryBasics.Vec3f0(v::Vec2, nr=0.0) = Vec3f0(v..., nr)
GeometryBasics.Vec3f0(v::Vec3) = Vec3f0(v...)
GeometryBasics.Vec4f0(v::Vec2, n1=0.0, n2=0.0) = Vec4f0(v..., n1, n2)
GeometryBasics.Vec4f0(v::Vec3, n1=0.0) = Vec4f0(v..., n1)

#----------------GeometryBasics-------------------------#
struct Cone{T} <: GeometryPrimitive{3, T}
    origin::Point3{T}
    extremity::Point3{T}
    r::T
end

GeometryBasics.origin(c::Cone{T}) where {T}    = c.origin
GeometryBasics.extremity(c::Cone{T}) where {T} = c.extremity
GeometryBasics.radius(c::Cone{T}) where {T}    = c.r
GeometryBasics.height(c::Cone{T}) where {T}    = norm(c.extremity - c.origin)
GeometryBasics.direction(c::Cone{T}) where {T} = (c.extremity .- c.origin) ./ GeometryBasics.height(c)

function GeometryBasics.rotation(c::Cone{T}) where T
    d3 = direction(c); u = GeometryBasics.@SVector [d3[1], d3[2], d3[3]]
    if abs(u[1]) > 0 || abs(u[2]) > 0
        v = GeometryBasics.@MVector [u[2], -u[1], T(0)]
    else
        v = GeometryBasics.@MVector [T(0), -u[3], u[2]]
    end
    normalize!(v)
    w = GeometryBasics.@SVector [u[2] * v[3] - u[3] * v[2], -u[1] * v[3] + u[3] * v[1], u[1] * v[2] - u[2] * v[1]]
    return hcat(v, w, u)
end

function GeometryBasics.decompose(PT::Type{Point{3, T}}, c::Cone, resolution = 30) where T
    isodd(resolution) && (resolution = 2 * div(resolution, 2))
    resolution = max(8, resolution); nbv = div(resolution, 2)
    M = GeometryBasics.rotation(c)
    h = GeometryBasics.height(c)
    position = 1; vertices = Vector{PT}(undef, nbv+2)
    for j = 1:nbv
        phi = T((2π * (j - 1)) / nbv)
        vertices[j] = PT(M * Point{3, T}(c.r * cos(phi), c.r * sin(phi),0)) + PT(c.origin)
    end
    vertices[end-1] = PT(c.origin)
    vertices[end] = PT(c.extremity)
    return vertices
end

function GeometryBasics.decompose(::Type{FT}, c::Cone, resolution = 30) where FT <: GeometryBasics.AbstractFace
    isodd(resolution) && (resolution = 2 * div(resolution, 2))
    resolution = max(8, resolution); nbv = div(resolution, 2)
    indexes = Vector{FT}(undef, resolution)
    index = 1
    for j = 1:nbv-1
        indexes[index] = (index,  nbv+1, index + 1)
        indexes[index+nbv] = (index,  index+1, nbv+2)
        index += 1
    end
    # indexes[index] = (index,  index + 1, nbv+1)
    # indexes[index+nbv] = (index,  nbv+2, index + 1)
    indexes[nbv] = (1, nbv+2, nbv)
    indexes[end] = (1, nbv, nbv+1)
    # indexes[end] = (1, 1, 1)
    return indexes
end

struct Arrow{T} <: GeometryPrimitive{3, T}
    origin::Point3{T}
    extremity::Point3{T}
    r::T #cylinder ratio
    length_ratio::T # height = height_cylinder * (1+length_ratio)
    radius_ratio::T # cone_radius = radius_ratio * r
end

GeometryBasics.origin(c::Arrow)    = c.origin
GeometryBasics.extremity(c::Arrow) = c.extremity
GeometryBasics.radius(c::Arrow)    = c.r
GeometryBasics.height(c::Arrow)    = norm(c.extremity - c.origin)
GeometryBasics.direction(c::Arrow) = (c.extremity .- c.origin) ./ GeometryBasics.height(c)

GeometryBasics.Cylinder(c::Arrow) =
    Cylinder(c.origin, direction(c) * height(c) / (1 + c.length_ratio), c.r)

Cone(c::Arrow) =
    Cone(direction(c) * height(c)/(1 + c.length_ratio), c.extremity, c.r * c.radius_ratio)

GeometryBasics.decompose(PT::Type{<:Point}, c::Arrow, resolution = 30) =
    [decompose(PT, Cylinder(c), resolution); decompose(PT, Cone(c), resolution)]

function GeometryBasics.decompose(::Type{FT}, c::Arrow, resolution = 30) where FT <: GeometryBasics.AbstractFace
    cylinder_indices = decompose(FT, Cylinder(c), resolution)
    last_id = maximum(maximum.(cylinder_indices))
    cone_indices = [id .+ last_id for id in decompose(FT, Cone(c), resolution)]
    return [cylinder_indices; cone_indices]
end

# const INSTANCEpD_MESHES = Dict{Symbol, BasicMesh}()
#
# struct InstancedAttributeMesh{D, T, FD, FT, AT <: NamedTuple} <: AbstractGlimpseMesh
#     basic      ::BasicMesh{D, T, FD, FT}
#     attributes ::Vector{AT}
# end
#
# function InstancedAttributeMesh(basic_symbol::Symbol, attributes::NamedTuple)
#     if !haskey(INSTANCED_MESHES, basic_symbol)
#         error("No instanced mesh `$basic_symbol` found.")
#     end
#     return InstancedAttributeMesh(INSTANCED_MESHES[basic_symbol], basic_symbol, attributes)
# end
#
# InstancedAttributeMesh(basic_symbol::Symbol, attributes::NamedTuple, geometry, args...) =
#     InstancedAttributeMesh(basic_symbol, attributes, BasicMesh(geometry, args...))
#
# InstancedAttributeMesh(basic_symbol::Symbol, geometry, args...; attributes...) =
#     InstancedAttributeMesh(basic_symbol, NamedTuple{keys(attributes)}(values(attributes)), BasicMesh(geometry, args...))
#
# basicmesh(mesh::InstancedAttributeMesh) = mesh.basic


#----------------------GLFW----------------------------#
glfw_destroy_current_context() = GLFW.DestroyWindow(GLFW.GetCurrentContext())

"""
Standard window hints for creating a plain context without any multisampling
or extra buffers beside the color buffer
"""
const GLFW_DEFAULT_WINDOW_HINTS = [(GLFW.SAMPLES,      0),
		                           (GLFW.DEPTH_BITS,   32),

		                           (GLFW.ALPHA_BITS,   8),
		                           (GLFW.RED_BITS,     8),
		                           (GLFW.GREEN_BITS,   8),
		                           (GLFW.BLUE_BITS,    8),

		                           (GLFW.STENCIL_BITS, 0),
		                           (GLFW.AUX_BUFFERS,  0),
		                           (GLFW.SCALE_TO_MONITOR, 1)]

glfw_standard_screen_resolution() =
	GLFW.GetPrimaryMonitor() |> GLFW.GetMonitorPhysicalSize |> values .|> x -> div(x, 1)

## Colorutils
import ColorTypes: RGBA, Colorant, RGB
ColorTypes.RGBA(x::T) where T<:Real = RGBA{T}(x,x,x,x)
ColorTypes.RGBA{T}(x) where T<:Real = RGBA{T}(T(x),T(x),T(x),T(x))

Base.length(::Type{<:RGBA}) = 4
Base.size(x::Type{<:Colorant}) = (length(x),)
Base.size(x::Type{<:RGB{Float32}}) = (3,)
Base.ndims(x::Type{Colorant}) = 1

const RGBAf0          = RGBA{Float32}
const RGBf0           = RGB{Float32}
const BLUE            = RGBf0(0.0, 0.0, 1.0)
const GREEN           = RGBf0(0.0, 1.0, 0.0)
const RED             = RGBf0(1.0, 0.0, 0.0)
const BLACK           = RGBf0(0.0, 0.0, 0.0)

