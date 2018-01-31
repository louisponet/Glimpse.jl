import GLAbstraction: VertexArray, bind, draw, unbind
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
    verts::AbstractMesh{<:StaticVector{D, GLfloat}, Face{FaceLength,Int}}
    uniforms::Dict{Symbol, Any}
    vao::Union{VertexArray, Void}
end

#it's required to at least have key positions
function Renderable(id, name, attributes::Dict{Symbol, Any}, uniforms=Dict{Symbol, Any}())
    mesh = homogenousmesh(attributes)
    println(supertype(typeof(mesh)))
    Renderable(id, name, mesh, uniforms, nothing)
end

function to_gpu(renderable::Renderable{D, FaceLength} where D) where FaceLength
    renderable.vao = VertexArray((renderable.verts.vertices, renderable.verts.color), facelength=FaceLength)
end

function bind(renderable::Renderable)
    if renderable.vao == nothing
        to_gpu(renderable)
    end
    bind(renderable.vao)
end

draw(renderable::Renderable) = draw(renderable.vao)
unbind(renderable::Renderable) = unbind(renderable.vao)


