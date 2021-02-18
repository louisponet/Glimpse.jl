#TypeDefs
const UniformDict     = Dict{Symbol, Any}
const SymAnyDict      = Dict{Symbol, Any}
const EmptyNamedTuple = NamedTuple{(), Tuple{}}
const VecOrT{T} = Union{Vector{T}, T}

# Gapped Arrays are used in systems
abstract type RenderPassKind end
abstract type RenderTargetKind end

abstract type AbstractGlimpseMesh end

const INSTANCED_MESHES = Dict{Type, AbstractGlimpseMesh}()

struct BasicMesh{D, T, FT} <: AbstractGlimpseMesh
    vertices ::Vector{Point{D, T}}
    faces    ::Vector{FT}
    normals  ::Vector{Vec{D, T}}
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
    function Diorama(name::Symbol, ledger::Ledger, renderloop_stages::Vector{Stage})
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

glimpse_call(func::Function) = @tspawnat 2 func()
