#TypeDefs
const UniformDict     = Dict{Symbol, Any}
const SymAnyDict      = Dict{Symbol, Any}
const EmptyNamedTuple = NamedTuple{(), Tuple{}}
const Area            = SimpleRectangle
const RGBAf0          = RGBA{Float32}
const RGBf0           = RGB{Float32}
const BLUE            = RGBf0(0.0, 0.0, 1.0)
const GREEN           = RGBf0(0.0, 1.0, 0.0)
const RED             = RGBf0(1.0, 0.0, 0.0)
const BLACK           = RGBf0(0.0, 0.0, 0.0)
const X_AXIS          = Vec3f0(1.0f0, 0.0  , 0.0)
const Y_AXIS          = Vec3f0(0.0,   1.0f0, 0.0)
const Z_AXIS          = Vec3f0(0.0,   0.0  , 1.0f0)

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

mutable struct Diorama <: AbstractLedger
    name      ::Symbol
	ledger    ::Ledger
	renderloop_stages::Vector{Stage}
    loop      ::Union{Task, Nothing}
    reupload  ::Bool
    function Diorama(name::Symbol, ledger::Ledger, renderloop_stages::Vector{Stage}; kwargs...)
        dio = new(name, ledger, renderloop_stages, nothing, true)

        makecurrentdio(dio)
        finalizer(free!, dio)
        return dio
    end
end

include("components.jl")
include("singletons.jl")
include("meshes.jl")
include("system.jl")
include("diorama.jl")



