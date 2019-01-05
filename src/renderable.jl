import GLAbstraction: VertexArray, Buffer, Program
import GLAbstraction: bind, draw, unbind, free!, attribute_location
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
    index       ::Int
    name        ::String
    verts       ::AbstractMesh{<:StaticVector{D, GLfloat}}
    uniforms    ::Dict{Symbol, Any}
    vao         ::Union{VertexArray, Nothing}
    renderpasses::Vector{Symbol}
end

function Renderable(index, name, mesh::H, attributes::Pair...; facelength=1, renderpasses=[:default], uniforms...) where H <: HMesh
    newmesh = isempty(attributes) ? H(mesh) : H(mesh, SymAnyDict(attributes))
    if newmesh.faces != Nothing[]
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

isuploaded(r::Renderable) = r.vao != nothing

function VertexArray(mesh::T, program::Program; kwargs...) where {T <: AbstractMesh}
    buffer_attribloc = Pair{Buffer, GLint}[]
    indices = nothing
    for name in fieldnames(T)
        field = getfield(mesh, name)
        if field == nothing || field == Nothing[]
            continue
        end
        if name == :faces
            indices = field
        else
            location = attribute_location(program, name)
            if location != -1
                push!(buffer_attribloc, Buffer(field) => location)
            else
            end
        end
    end
    if indices == nothing
        return VertexArray(buffer_attribloc, nothing; kwargs...)
    else
        return VertexArray(buffer_attribloc, indices; kwargs...)
    end
end


bind(renderable::Renderable) = GLAbstraction.bind(renderable.vao)

Base.eltype(::Type{Renderable{D, F}}) where {D, F} = (D, F)

draw(renderable::Renderable) = draw(renderable.vao)
unbind(renderable::Renderable) = unbind(renderable.vao)

function free!(r::Renderable)
    if r.vao != nothing
        r.vao = free!(r.vao)
    end
end

function set_uniforms!(renderable, uniforms::Pair{Symbol, <:Any}...)
    for (u, v) in uniforms
        renderable.uniforms[u] = v
    end
end
