import GLAbstraction: VertexArray, Buffer, Program, BufferAttachmentInfo
import GLAbstraction: bind, draw, unbind, free!, attribute_location, INVALID_ATTRIBUTE
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



MeshRenderable(renderee, renderpasses::Vector{Symbol}, args...; uniforms...) =
    MeshRenderable(renderee, BasicMesh(renderee, args...), UniformDict(uniforms), RenderPassDict(renderpasses), false)
MeshRenderable(renderee, renderpasses::Vector{Symbol}, attributes::NamedTuple, args...; uniforms...) =
    MeshRenderable(renderee, AttributeMesh(attributes, renderee, args...), UniformDict(uniforms), RenderPassDict(renderpasses) , false)

function MeshRenderable(renderee::HyperSphere, renderpasses::Vector{Symbol}, attributes::NamedTuple, args...; uniforms...)
    unis = UniformDict(uniforms)
    if !haskey(unis, :modelmat)
        unis[:modelmat] = translmat(renderee.center) * scalemat(Point3f0(renderee.r))
    end
    MeshRenderable(renderee, AttributeMesh(attributes, renderee, args...), unis, RenderPassDict(renderpasses) , false)
end

function InstancedMeshRenderable(renderee::T, renderpasses::Vector{Symbol}, attributes::NamedTuple, args...; uniforms...) where T
    if haskey(INSTANCED_MESHES, T)
        mesh = INSTANCED_MESHES[T]
    else
        if isempty(attributes)
            mesh = INSTANCED_MESHES[T] = BasicMesh(renderee, args...)
        else
            mesh = INSTANCED_MESHES[T] = AttributeMesh(attributes, BasicMesh(renderee, args...))
        end
    end
    unis = UniformDict(uniforms)
    if !haskey(unis, :modelmat) && T <: HyperSphere
        unis[:modelmat] = translmat(renderee.center) * scalemat(Point3f0(renderee.r))
    end
    return MeshRenderable(renderee, mesh, unis, RenderPassDict(renderpasses), true)
end

RenderPassDict(renderpasses::Vector{Symbol}) = Dict([r => false for r in renderpasses])

uniforms(renderable::MeshRenderable) = renderable.uniforms
Base.eltype(::Type{MeshRenderable{T, MT}}) where {T, MT} = (T, MT)
Base.eltype(renderable::MR) where {MR <: MeshRenderable} = eltype(MR)
meshtype(renderable::MR) where {MR <: MeshRenderable} = eltype(MR)[2]

mesh(renderable::MeshRenderable) = renderable.mesh
basicmesh(renderable::MeshRenderable) = basicmesh(mesh(renderable))

isinstanced(rend::MeshRenderable) = rend.instanced

haspass(rend::MeshRenderable, pass::RenderPass{name}) where name = haspass(rend, name)
haspass(rend::MeshRenderable, pass_name::Symbol) = haskey(rend.renderpasses, pass_name)

isuploaded(rend::MeshRenderable, pass_name::Symbol) = rend.renderpasses[pass_name]



function GLRenderable(renderable::MeshRenderable, renderpass)
    vao      = VertexArray(renderable.mesh, main_program(renderpass))
    unisyms  = keys(uniforms(renderable)) ∩ vcat(valid_uniforms(renderpass)...)
    unis = NamedTuple{(unisyms...,)}([uniforms(renderable)[k] for k in unisyms])

    return GLRenderable(renderable, vao, unis)
end

# For instanced renderables, all renderable uniforms must be in buffers to the vao
function InstancedGLRenderable(renderables::Vector{<:MeshRenderable}, pass)
    @assert all(mesh.(renderables) .== (mesh(renderables[1]),)) "Some renderables to be instanced do not have the same mesh."
    if !all(keys.(uniforms.(renderables)) .== (keys(uniforms(renderables[1])),))
        @warn "Some renderables to be instanced have uniforms that aren't present in all of them. Only the uniforms of the first one will be used."
    end

    unis = Dict{Symbol, Any}([k => [v] for (k, v) in uniforms(renderables[1])])
    for renderable in renderables[2:end]
        for (k, v) in uniforms(renderable)
            push!(unis[k], v)
        end
    end
    buffers = [generate_buffers(mesh(renderables[1]), main_instanced_program(pass));
               generate_buffers(unis, main_instanced_program(pass))]
    indices = faces(mesh(renderables[1])) .- GLint(1)

# hmm using the first renderable as the source feels not quite right but fine whatever for now.
    return GLRenderable(renderables[1], VertexArray(buffers, indices, length(renderables)), NamedTuple())
end

function generate_buffers(uniform_dict::UniformDict, program::Program)
    buffers = BufferAttachmentInfo[]
    for (k, v) in uniform_dict
        loc = attribute_location(program, k)
        if loc != INVALID_ATTRIBUTE
            push!(buffers, BufferAttachmentInfo(loc, Buffer(v), GLint(1)))
        end
    end
    return buffers
end

isinstanced(renderable::GLRenderable) = isinstanced(renderable.source)

function upload_uniforms(program::Program, renderable::GLRenderable)
    for (key, val) in pairs(renderable.uniforms)
        set_uniform(program, key, val)
    end
end

bind(renderable::GLRenderable)   = GLAbstraction.bind(renderable.vertexarray)
draw(renderable::GLRenderable)   = draw(renderable.vertexarray)
unbind(renderable::GLRenderable) = unbind(renderable.vertexarray)


function free!(r::GLRenderable)
    free!(r.vertexarray)
end


#api

function translate(r::AbstractRenderable, vector::Vec3)
	r.uniforms[:modelmat] = translmat(convert(Vec3{Float32}, vector)) * r.uniforms[:modelmat]
	r.should_upload = true
end









