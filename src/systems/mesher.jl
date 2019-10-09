
# This system constructs all the meshes from geometries. These meshes will then be used to be uploaded to OpenGL
abstract type Mesher <: System end

struct PolygonMesher <: Mesher end

requested_components(::PolygonMesher) = (PolygonGeometry, Mesh)

struct FileMesher <: Mesher end

requested_components(::FileMesher) = (FileGeometry, Mesh)

struct VectorMesher <: Mesher end

requested_components(::VectorMesher) = (VectorGeometry, Mesh)

geometry_type(::Type{PolygonMesher}) = PolygonGeometry
geometry_type(::Type{VectorMesher}) = VectorGeometry
geometry_type(::Type{FileMesher}) = FileGeometry

function update(::Union{M}, m::Manager) where {M<:Mesher}
	mesh = m[Mesh]
	geom = m[geometry_type(M)]
	it = entities(geom, exclude=(mesh,))
	@inbounds for e in it
		mesh[e] = Mesh(BasicMesh(geom[e].geometry))
	end
end

struct FunctionMesher <: Mesher end

requested_components(::FunctionMesher) = (FunctionGeometry, Mesh, Grid)

struct DensityMesher <: Mesher end

requested_components(::DensityMesher) = (DensityGeometry, Mesh, Grid)

function update(::Union{FunctionMesher, DensityMesher}, m::Manager)
	mesh = m[Mesh]
	geom = m[FunctionGeometry]
	grid = m[Grid]
	it = entities(geom, grid, exclude=(mesh,))
	@inbounds for e in it
		points = grid[e].points
		vertices, ids = marching_cubes(geom[e].geometry, points, geom[e].iso)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
		mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end
end

struct FunctionColorizer <: System end

requested_components(::FunctionColorizer) = (FunctionColor, Mesh, BufferColor)

function update(::FunctionColorizer, m::Manager)
	colorbuffers = m[BufferColor]
	fcolor       = m[FunctionColor]
	mesh         = m[Mesh]
	it = entities(fcolor, mesh, exclude=(colorbuffers,))
	@inbounds for e in it
		colorbuffers[e] = BufferColor(fcolor[e].color.(mesh[e].mesh.vertices))
	end
end
