#TypeDefs
const UniformDict     = Dict{Symbol, Any}
const SymAnyDict      = Dict{Symbol, Any}
const EmptyNamedTuple = NamedTuple{(), Tuple{}}
const Area            = SimpleRectangle
const RGBAf0          = RGBA{Float32}
const RGBf0           = RGB{Float32}
const BLUE            = RGBAf0(0.0, 0.0, 1.0, 1.0)
const GREEN           = RGBAf0(0.0, 1.0, 0.0, 1.0)
const RED             = RGBAf0(1.0, 0.0, 0.0, 1.0)

@enum CamKind pixel orthographic perspective

# Gapped Arrays are used in systems
abstract type RenderPassKind end
abstract type RenderTargetKind end

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

mutable struct Diorama <: ECS.AbstractManager
    name       ::Symbol
	manager    ::ECS.Manager
    loop       ::Union{Task, Nothing}
    reupload   ::Bool
    function Diorama(name::Symbol, manager::ECS.Manager; interactive=true, kwargs...)
        dio = new(name, manager, nothing, true)

        makecurrentdio(dio)
    	interactive && expose(dio; kwargs...)
        finalizer(free!, dio)
        return dio
    end
end

include("components.jl")
include("singletons.jl")
include("meshes.jl")
include("system.jl")
include("diorama.jl")



