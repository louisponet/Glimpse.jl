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

mutable struct Renderable{D, FaceLength} #D for dimensions
    id::Int
    name::Symbol
    verts::AbstractMesh{<:StaticVector{D, GLfloat}}
    uniforms::Dict{Symbol, Any}
    vao::Union{VertexArray, Void}
end

#it's required to at least have key positions
function Renderable(id, name, attributes::Dict{Symbol, Any}, uniforms=Dict{Symbol, Any}(); facelength=1) # not too happy about this facelength
    mesh = homogenousmesh(attributes)
    if mesh.faces != Void[]
        facelength = length(eltype(mesh.faces))
    end
    Renderable{length(eltype(mesh.vertices)), facelength}(id, name, mesh, uniforms, nothing)
end

Renderable{FaceLength}(args...) where FaceLength = Renderable(args...; facelength=FaceLength)

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