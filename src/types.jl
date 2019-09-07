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
include("gapped_vector.jl")

abstract type Singleton end

abstract type RenderPassKind end
abstract type RenderTargetKind end

abstract type ComponentData end
abstract type AbstractComponent{T <: ComponentData} end
Base.eltype(::AbstractComponent{T}) where {T <: ComponentData} = T

struct Component{T <: ComponentData} <: AbstractComponent{T}
	id  ::Int
	data::GappedVector{T}
end

struct SharedComponent{T <: ComponentData} <: AbstractComponent{T}
	id    ::Int
	data  ::GappedVector{Int} #These are basically the ids
	shared::Vector{T}
end

#Should I use DataFrames/Tables?
struct Entity #we will create a name component #maybe it's not so bad that these are not contiguous?
	id::Int
end

abstract type System end

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

mutable struct Diorama
    name       ::Symbol

    entities  ::Vector{Entity}
    components::Vector{AbstractComponent}
	singletons::Vector{Singleton}
    systems   ::Vector{System}
    
    loop       ::Union{Task, Nothing}
    reupload   ::Bool
    function Diorama(name, entities, components,  singletons, systems; interactive=true, kwargs...)
        dio = new(name, entities, components, singletons, systems, nothing, true)

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



