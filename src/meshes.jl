import GeometryBasics: normals, faces, decompose, normals
import GLAbstraction: INVALID_ATTRIBUTE, attribute_location, GEOMETRY_DIVISOR

function BasicMesh(geometry::T, ft = TriangleFace{3,GLint}) where {T}
    return error("Please implement a `BasicMesh` constructor for type $T.")
end

function BasicMesh(geometry::AbstractGeometry{D,T}, ft = TriangleFace{GLint}) where {D,T}
    vertices = collect(decompose(Point{D,T}, geometry))
    faces    = collect(decompose(ft, geometry))
    norms    = collect(normals(vertices, faces))
    return BasicMesh(vertices, faces, norms)
end

function BasicMesh(geometry::HyperSphere, complexity = 2)
    vertices, normals, faces = generate_sphere(complexity)
    return BasicMesh(vertices, faces, normals)
end

function BasicMesh(geometry::String)
    faces, vertices, normals = getfield.((load(geometry),), [:faces, :vertices, :normals])
    return BasicMesh(vertices, faces, Vec3f0.(normals))
end

function BasicMesh(vec_geometry::Vector)
    vertices = Point3f0.(vec_geometry)
    faces    = SimplexFace{1}.([i for i in 1:length(vec_geometry)])
    normals  = Vec3f0[]
    return BasicMesh(vertices, faces, normals)
end

Base.eltype(::Type{BasicMesh{D,T,FT}}) where {D,T,FT} = (D, T, FT)
Base.eltype(mesh::BM) where {BM<:BasicMesh} = eltype(BM)

basicmesh(mesh::BasicMesh)          = mesh
vertices(mesh::AbstractGlimpseMesh) = basicmesh(mesh).vertices
normals(mesh::AbstractGlimpseMesh)  = basicmesh(mesh).normals
faces(mesh::AbstractGlimpseMesh)    = basicmesh(mesh).faces

facelength(mesh::AbstractGlimpseMesh) = facelength(basicmesh(mesh))
facelength(mesh::BasicMesh{D,T,FT} where {D,T,FD}) where {FT} = length(FT)

Base.length(mesh::AbstractGlimpseMesh) = length(vertices(mesh))

function Base.isequal(mesh::BasicMesh, mesh2::BasicMesh)
    return mesh.faces == mesh2.faces && mesh.vertices == mesh2.vertices
end
import Base: ==
==(mesh::BasicMesh, mesh2::BasicMesh) = isequal(mesh, mesh2)

AttributeMesh(attributes, args...) = AttributeMesh(attributes, BasicMesh(args...))
AttributeMesh(args...; attributes...) = AttributeMesh(attributes.data, BasicMesh(args...))

Base.eltype(::Type{AttributeMesh{AT,BM}}) where {AT,BM} = (AT, eltype(BM)...)
Base.eltype(mesh::AM) where {AM<:AttributeMesh} = eltype(AM)

basicmesh(mesh::AttributeMesh) = mesh.basic

function generate_buffers(program::Program, mesh::BasicMesh)
    buffers = BufferAttachmentInfo[]
    for n in (:vertices, :normals)
        loc = attribute_location(program, n)
        if loc != INVALID_ATTRIBUTE
            push!(buffers,
                  BufferAttachmentInfo(n, loc, Buffer(getfield(mesh, n)), GEOMETRY_DIVISOR))
        end
    end
    return buffers
end

function generate_buffers(program::Program, mesh::AttributeMesh{AT}) where {AT}
    buffers = generate_buffers(basicmesh(mesh), program)
    buflen  = length(mesh)
    for (name, val) in pairs(mesh.attributes)
        loc = attribute_location(program, name)
        if loc != INVALID_ATTRIBUTE
            vallen = length(val)
            if vallen == buflen
                push!(buffers,
                      BufferAttachmentInfo(name, loc, Buffer(val), GEOMETRY_DIVISOR))
            elseif !isa(val, Vector)
                push!(buffers,
                      BufferAttachmentInfo(name, loc, Buffer(fill(val, buflen)),
                                           GEOMETRY_DIVISOR))
            end
        end
    end
    return buffers
end

function GLA.VertexArray(program::Program, mesh::AbstractGlimpseMesh; extra_attributes...)
    return VertexArray(generate_buffers(program, mesh; extra_attributes...),
                       faces(mesh) .- GLint(1))
end
