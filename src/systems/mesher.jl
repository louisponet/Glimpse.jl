
# This system constructs all the meshes from geometries. These meshes will then be used to be uploaded to OpenGL
abstract type Mesher <: System end

struct PolygonMesher <: Mesher end

ECS.requested_components(::PolygonMesher) = (PolygonGeometry, Mesh)

struct FileMesher <: Mesher end

ECS.requested_components(::FileMesher) = (FileGeometry, Mesh)

struct VectorMesher <: Mesher end

ECS.requested_components(::VectorMesher) = (VectorGeometry, Mesh)

geometry_type(::Type{PolygonMesher}) = PolygonGeometry
geometry_type(::Type{VectorMesher}) = VectorGeometry
geometry_type(::Type{FileMesher}) = FileGeometry

function ECS.update(::Union{M}, m::AbstractManager) where {M<:Mesher}
	mesh = m[Mesh]
	geom = m[geometry_type(M)]
	for e in @entities_in(geom && !mesh)
		mesh[e] = Mesh(BasicMesh(geom[e].geometry))
	end
end

struct FunctionMesher <: Mesher end

ECS.requested_components(::FunctionMesher) = (FunctionGeometry, Mesh, Grid)

struct DensityMesher <: Mesher end

ECS.requested_components(::DensityMesher) = (DensityGeometry, Mesh, Grid)

function ECS.update(::Union{FunctionMesher, DensityMesher}, m::AbstractManager)
	mesh = m[Mesh]
	geom = m[FunctionGeometry]
	grid = m[Grid]
	for e in @entities_in(geom && grid && !mesh)
		points = grid[e].points
		vertices, ids = marching_cubes(geom[e].geometry, points, geom[e].iso)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
		mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end
end

struct FunctionColorizer <: System end

ECS.requested_components(::FunctionColorizer) = (FunctionColor, Mesh, BufferColor)

function ECS.update(::FunctionColorizer, m::AbstractManager)
	colorbuffers = m[BufferColor]
	fcolor       = m[FunctionColor]
	mesh         = m[Mesh]
	for e in @entities_in(fcolor && mesh && !colorbuffers)
		colorbuffers[e] = BufferColor(fcolor[e].color.(mesh[e].mesh.vertices))
	end
end
