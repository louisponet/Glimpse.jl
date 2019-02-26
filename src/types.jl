#TypeDefs
const UniformDict     = Dict{Symbol, Any}
const SymAnyDict      = Dict{Symbol, Any}
const EmptyNamedTuple = NamedTuple{(), Tuple{}}
const Area            = SimpleRectangle

abstract type AbstractGlimpseMesh end

const INSTANCED_MESHES = Dict{Type, AbstractGlimpseMesh}()

struct BasicMesh{D, T, FD, FT} <: AbstractGlimpseMesh
    vertices ::Vector{Point{D, T}}
    faces    ::Vector{Face{FD, FT}}
    normals  ::Vector{Point{D, T}}
end

struct AttributeMesh{AT<:NamedTuple, BM <: BasicMesh} <: AbstractGlimpseMesh
    attributes ::AT
    basic      ::BM
end

#Should we really dispatch on the original type? Maybe
abstract type AbstractRenderable end

mutable struct MeshRenderable{T, MT<:AbstractGlimpseMesh} <: AbstractRenderable
    renderee     ::T #the original type
    mesh         ::MT
    uniforms     ::UniformDict
    renderpasses ::Dict{Symbol, Bool}
    instanced    ::Bool
    should_upload::Bool
    function MeshRenderable(r::T, m::MT, u, rp, i) where {T, MT}
	    return new{T, MT}(r, m, u, rp, i, true)
    end
end

struct GLRenderable{MR <: MeshRenderable, VT <: VertexArray, NT <: NamedTuple}
    source         ::MR
    vertexarray    ::VT
    uniforms       ::NT
end

mutable struct Camera{Kind, Dim, T}
    eyepos ::Vec{Dim, T}
    lookat ::Vec{Dim, T}
    up     ::Vec{Dim, T}
    right  ::Vec{Dim, T}
    fov    ::T
    near   ::T
    far    ::T
    view   ::Mat4{T}
    proj        ::Mat4{T}
    projview    ::Mat4{T}
    rotation_speed    ::T
    translation_speed ::T
    mouse_pos         ::Vec{2, T}

    function (::Type{Camera{Kind}})(eyepos::Vec{Dim, T}, lookat, up, right, area, fov, near, far, rotation_speed, translation_speed) where {Kind, Dim, T}

        up    = normalizeperp(lookat - eyepos, up)
        right = normalize(cross(lookat - eyepos, up))

        viewm = lookatmat(eyepos, lookat, up)
        projm = projmat(Kind, area, near, far, fov)
        new{Kind, Dim, T}(eyepos, lookat, up, right, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed, Vec2f0(0))
    end
end

abstract type Light{T} end

mutable struct PointLight{T <: AbstractFloat} <: Light{T}
    position::Vec3{T}
    diffuse ::T
    specular::T
    ambient ::T
    color   ::RGB{T}
end

PointLight() = PointLight{Float32}(Vec3f0(0,0,20), 0.8f0, 1.0f0, 0.8f0, RGB{Float32}(1,1,1))

#Direction always has to be normalized!
mutable struct DirectionLight{T <: AbstractFloat} <: Light{T}
    direction::Vec3{T}
    diffuse ::T
    specular::T
    ambient ::T
    color   ::RGB{T}
end

mutable struct Scene
    name::Symbol
    renderables::Vector{<:MeshRenderable}
    camera::Camera
    lights::Vector{<:Light}
end

mutable struct Canvas <: GLA.AbstractContext
    name          ::Symbol
    id            ::Int
    area          ::Area
    native_window ::GLFW.Window
    background    ::Colorant{Float32, 4}
    callbacks     ::Dict{Symbol, Any}
	fullscreenvao ::VertexArray
	function Canvas(name::Symbol, id::Int, area, nw, background, callback_dict)
		obj = new(name, id, area, nw, background, callback_dict)
		finalizer(free!, obj)
		return obj
	end
    # framebuffer::FrameBuffer # this will become postprocessing passes. Each pp has a
end

const RenderTarget     = Union{FrameBuffer, Canvas}
const RenderTargetDict = Dict{Symbol, RenderTarget}
const ProgramDict      = Dict{Symbol, Program}

mutable struct Screen
    name      ::Symbol
    id        ::Int
    area      ::Area
    canvas    ::Union{Canvas, Nothing}
    background::Colorant
    parent    ::Union{Screen, Nothing}
    children  ::Vector{Screen}
    hidden    ::Bool # if window is hidden. Will not render
    function Screen(name      ::Symbol,
                    area      ::Area,
                    canvas    ::Canvas,
                    background::Colorant,
                    parent    ::Union{Screen, Nothing},
                    children  ::Vector{Screen},
                    hidden    ::Bool)
        id = new_screen_id()
        canvas.id = id
        obj = new(name, id, area, canvas,background, parent, children, hidden)
        finalizer(free!, obj)
        return obj
    end
end

mutable struct RenderPass{Name, NT <: NamedTuple}
    # id::Int
    programs              ::ProgramDict
    targets               ::RenderTargetDict
    renderables           ::Vector{GLRenderable}
    options               ::NT
    function RenderPass{name}(programs::ProgramDict, fbs::RenderTargetDict, renderables::Vector{GLRenderable}, options::NT) where {name, NT <: NamedTuple}
        obj = new{name, NT}(programs, fbs, renderables, options)
        finalizer(free!, obj)
        return obj
    end
end

mutable struct Diorama
    name     ::Symbol
    scene    ::Scene
    screen   ::Union{Screen, Nothing}
    pipeline ::Union{Vector{RenderPass}, Nothing}
    loop     ::Union{Task, Nothing}
    reupload ::Bool
    function Diorama(name, scene, screen, pipeline; interactive=false, kwargs...)
        dio = new(name, scene, screen, pipeline, nothing, true)
        makecurrentdio(dio)
        expose(dio; kwargs...)
        finalizer(free!, dio)
        return dio
    end
end

include("meshes.jl")
include("renderable.jl")
include("light.jl")
include("camera.jl")
include("scene.jl")
include("canvas.jl")
include("screen.jl")
include("renderpass.jl")

include("diorama.jl")



