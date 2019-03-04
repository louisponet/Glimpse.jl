#TypeDefs
const UniformDict     = Dict{Symbol, Any}
const SymAnyDict      = Dict{Symbol, Any}
const EmptyNamedTuple = NamedTuple{(), Tuple{}}
const Area            = SimpleRectangle
const RGBAf0          = RGBA{Float32}
const RGBf0           = RGB{Float32}
@enum CamKind pixel orthographic perspective

#Should I use DataFrames/Tables?
struct Entity{NT <: NamedTuple} #we will create a name component #maybe it's not so bad that these are not contiguous?
	id       ::Int
	data_ids ::NT
end

struct Component{name, T}
	id   ::Int
	data ::Vector{T}
end

abstract type SystemKind end

struct System{Kind <: SystemKind, T <: Tuple} #T has the components 
	components::T
end

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

mutable struct Scene
    name::Symbol
    entities   ::Vector{Entity}
    components ::Vector{Component}
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
    # renderables           ::Vector{GLRenderable}
    options               ::NT
    function RenderPass{name}(programs::ProgramDict, fbs::RenderTargetDict, options::NT) where {name, NT <: NamedTuple}
        obj = new{name, NT}(programs, fbs, options)
        finalizer(free!, obj)
        return obj
    end
end

mutable struct SimData
	time  ::Float64
	dtime ::Float64
	frames::Int
end

mutable struct Diorama
    name     ::Symbol
    scene    ::Scene
    systems  ::Vector{System}
    screen   ::Union{Screen, Nothing}
    pipeline ::Union{Vector{RenderPass}, Nothing}
    loop     ::Union{Task, Nothing}
    reupload ::Bool
    simdata  ::SimData
    function Diorama(name, scene, systems, screen, pipeline; interactive=false, kwargs...)
        dio = new(name, scene, systems, screen, pipeline, nothing, true, SimData(time(),0.0, 0))
        makecurrentdio(dio)
        expose(dio; kwargs...)
        finalizer(free!, dio)
        return dio
    end
end
include("components.jl")
include("meshes.jl")
include("renderable.jl")
include("light.jl")
include("camera.jl")
include("scene.jl")
include("canvas.jl")
include("screen.jl")
include("renderpass.jl")

include("diorama.jl")



