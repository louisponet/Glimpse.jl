import GLAbstraction: VertexArray, draw, unbind, free!
import GeometryTypes: HomogenousMesh, homogenousmesh, StaticVector

# struct ColorVertex{Dim, T, ColorT} <: AbstractVertex
#     position ::SVector{Dim, T}
#     color    ::ColorT

# struct Vertex{Dim, T, ColorT} <: AbstractVertex
#     position ::SVector{Dim, T}
#     normal   ::SVector{Dim, T}
#     color    ::ColorT
#     uv       ::SVector{2, Int}
# end
# Vertex(position::SVector{D, V}) where V = Vertex(position, zero(V), zero(RGB), zero(Vec{2, V}))
# Vertex(position::SVector{D, V}, normal::SVector{D, V}) where V = Vertex(position, normal, zero(RGB), zero(Vec{2, V}))
# Vertex(position::SVector{D, V}, normal::SVector{D, V}, color::Colorant) where V = Vertex(position, normal, color, zero(Vec{2, V}))
# Vertex(position::SVector{D, V}, normal::SVector{D, V}, color::Colorant, uv) where V = Vertex(position, normal, color, uv)

#TODO: probably the index should be only set by the scene anyway, so always default to 0 maybe.
#      Although I could foresee that you first define all the renderables then throw them into the
#      scene in the correct order.
mutable struct Renderable{D, FaceLength} #D for dimensions
    index::Int
    name::Symbol
    verts::AbstractMesh{<:StaticVector{D, GLfloat}}
    uniforms::Dict{Symbol, Any}
    vao::Union{VertexArray, Void}
    renderpasses::Vector{Symbol}
end

function Renderable(index, name, mesh::H, attributes::Pair...; facelength=1, renderpasses=[:default], uniforms...) where H <: HMesh
    newmesh = isempty(attributes) ? H(mesh) : H(mesh, SymAnyDict(attributes))
    if newmesh.faces != Void[]
        facelength = length(eltype(newmesh.faces))
    end
    unidict = SymAnyDict(uniforms)
    if !haskey(unidict, :modelmat) unidict[:modelmat] = Eye4f0() end
    if !haskey(unidict, :specpow)   unidict[:specpow]   = 0.9f0    end
    if !haskey(unidict, :specint)   unidict[:specint]   = 0.6f0    end

    return Renderable{length(eltype(mesh.vertices)), facelength}(index, name, newmesh, unidict, nothing, renderpasses)
end

Renderable(index, name, attributes::Pair...; kwargs...) = Renderable(index, name, homogenousmesh(SymAnyDict(attributes)); kwargs...)

Renderable{FaceLength}(args...; kwargs...) where FaceLength = Renderable(args...; facelength=FaceLength, kwargs...)

function VertexArray(mesh::AbstractMesh; kwargs...)
    to_vao = []
    indices = nothing
    for name in fieldnames(mesh)
        field = getfield(mesh, name)
        if field == nothing || field == Void[]
            continue
        end
        if name == :faces
            indices = field
        else
            push!(to_vao, field)
        end
    end
    if indices == nothing
        return VertexArray((to_vao...); kwargs...)
    else
        return VertexArray((to_vao...), indices; kwargs...)
    end
end

function to_gpu(renderable::Renderable{D, FaceLength} where D) where FaceLength
    renderable.vao = VertexArray(renderable.verts, facelength=FaceLength)
end

function Base.bind(renderable::Renderable)
    if renderable.vao == nothing
        to_gpu(renderable)
    end
    Base.bind(renderable.vao)
end

Base.eltype(::Type{Renderable{D, F}}) where {D, F} = (D, F)

draw(renderable::Renderable) = draw(renderable.vao)
unbind(renderable::Renderable) = unbind(renderable.vao)

function free!(r::Renderable)
    if r.vao != nothing
        r.vao = free!(r.vao)
    end
end
