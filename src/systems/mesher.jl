
# This system constructs all the meshes from geometries. These meshes will then be used to be uploaded to OpenGL
abstract type Mesher <: System end

struct PolygonMesher <: Mesher end

Overseer.requested_components(::PolygonMesher) = (PolygonGeometry, Mesh)

struct FileMesher <: Mesher end

Overseer.requested_components(::FileMesher) = (FileGeometry, Mesh)

struct VectorMesher <: Mesher end

Overseer.requested_components(::VectorMesher) = (VectorGeometry, Mesh)

geometry_type(::Type{PolygonMesher}) = PolygonGeometry
geometry_type(::Type{VectorMesher}) = VectorGeometry
geometry_type(::Type{FileMesher}) = FileGeometry

function Overseer.update(::Union{M}, m::AbstractLedger) where {M<:Mesher}
    mesh = m[Mesh]
    geom = m[geometry_type(M)]
    it = @entities_in(geom && !mesh)

    length(it) == 0 && return

    for e in it
        parid = Entity(geom, findfirst(x -> x.geometry == e.geometry, geom.data))
        if parid == e # Geometry was not added to meshes yet
            mesh[e] = Mesh(BasicMesh(e.geometry))
        else
            mesh[e] = parid
        end
    end
end

struct FunctionMesher <: Mesher end

Overseer.requested_components(::FunctionMesher) = (FunctionGeometry, Mesh, Grid)

struct DensityMesher <: Mesher end

Overseer.requested_components(::DensityMesher) = (DensityGeometry, DensityColor, Mesh, Grid)

function Overseer.update(::Union{FunctionMesher,DensityMesher}, m::AbstractLedger)
    mesh = m[Mesh]
    grid = m[Grid]
    dens_c = m[DensityColor]
    for geom in (m[FunctionGeometry], m[DensityGeometry])
        for e in @entities_in(geom && grid && !mesh)
            points = grid[e].points
            vertices, ids = marching_cubes(geom[e].geometry, points, geom[e].iso)
            if isempty(vertices)
                continue
            end
            faces = [GeometryBasics.TriangleFace{GLint}(i, i + 1, i + 2)
                     for i in 1:3:length(vertices)]
            norms = length(faces) == 0 ? Vec3f0[] : normals(vertices, faces)
            mesh[e] = Mesh(BasicMesh(vertices, faces, norms))
            if e in dens_c
                d = dens_c[e]
                m[BufferColor][e] = BufferColor(map(x -> d.color[x...], ids))
            end
        end
    end
end

struct FunctionColorizer <: System end

Overseer.requested_components(::FunctionColorizer) = (FunctionColor, Mesh, BufferColor)

function Overseer.update(::FunctionColorizer, m::AbstractLedger)
    for e in @entities_in(m, FunctionColor && Mesh && !BufferColor)
        e[BufferColor] = BufferColor(e.color.(e.mesh.vertices))
    end
end
