import GLAbstraction: VertexArray, Buffer, Program
import GLAbstraction: bind, draw, unbind, free!, attribute_location
import GeometryTypes: HomogenousMesh, homogenousmesh, StaticVector

# function MeshRenderable(index, name, mesh::H, attributes::Pair...; facelength=1, renderpasses=[:default], uniforms...) where H <: HMesh
#     newmesh = isempty(attributes) ? H(mesh) : H(mesh, SymAnyDict(attributes))
#     if newmesh.faces != Nothing[]
#         facelength = length(eltype(newmesh.faces))
#     end
#     unidict = SymAnyDict(uniforms)
#     if !haskey(unidict, :modelmat)  unidict[:modelmat] = Eye4f0() end
#     if !haskey(unidict, :specpow)   unidict[:specpow]   = 0.9f0    end
#     if !haskey(unidict, :specint)   unidict[:specint]   = 0.6f0    end
#
#     return MeshRenderable{length(eltype(mesh.vertices)), facelength}(index, name, newmesh, unidict, nothing, renderpasses)
# end

#---------------------- New renderables ---------------- #
const UniformDict = Dict{Symbol, Any}
mutable struct MeshRenderable{T, MT<:AbstractGlimpseMesh}
    renderee     ::T #the original type
    mesh         ::MT
    uniforms     ::UniformDict
    renderpasses ::Dict{Symbol, Bool}
end

MeshRenderable(renderee, renderpasses::Vector{Symbol}, args...; uniforms...) =
    MeshRenderable(renderee, BasicMesh(renderee, args...), UniformDict(uniforms), ([r => false for r in renderpasses]))
MeshRenderable(renderee, renderpasses::Vector{Symbol}, attributes::NamedTuple, args...; uniforms...) =
    MeshRenderable(renderee, AttributeMesh(attributes, renderee, args...), UniformDict(uniforms), Dict([r => false for r in renderpasses]))

uniforms(renderable::MeshRenderable) = renderable.uniforms
Base.eltype(::Type{MeshRenderable{T, MT}}) where {T, MT} = (T, MT)
Base.eltype(renderable::MR) where {MR <: MeshRenderable} = eltype(MR)
meshtype(renderable::MR) where {MR <: MeshRenderable} = eltype(MR)[2]

struct GLRenderable{MR <: MeshRenderable, VT <: VertexArray, NT <: NamedTuple}
    source         ::MR
    vertexarray    ::VT
    uniforms       ::NT
end

function GLRenderable(renderable::MeshRenderable, renderpass)
    vao      = VertexArray(renderable.mesh, main_program(renderpass))
    unisyms  = keys(uniforms(renderable)) ∩ vcat(valid_uniforms(renderpass)...)
    unis = NamedTuple{(unisyms...,)}([uniforms(renderable)[k] for k in unisyms])

    return GLRenderable(renderable, vao, unis)
end

function set_uniforms(program::Program, renderable::GLRenderable)
    for (key, val) in pairs(renderable.uniforms)
        set_uniform(program, key, val)
    end
end

bind(renderable::GLRenderable)   = GLAbstraction.bind(renderable.vertexarray)
draw(renderable::GLRenderable)   = draw(renderable.vertexarray)
unbind(renderable::GLRenderable) = unbind(renderable.vertexarray)


function render(renderables::Vector{GLRenderable}, program::Program)
    for rend in renderables
        bind(rend)
        set_uniforms(program, rend)
        draw(rend)
    end
    unbind(renderables[end])
end

function free!(r::GLRenderable)
    free!(r.vertexarray)
end
