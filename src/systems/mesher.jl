
# This system constructs all the meshes from geometries. These meshes will then be used to be uploaded to OpenGL
abstract type Mesher <: System end

struct PolygonMesher <: Mesher end

requested_components(::PolygonMesher) = (PolygonGeometry, Mesh)

struct FileMesher <: Mesher end

requested_components(::FileMesher) = (FileGeometry, Mesh)

struct VectorMesher <: Mesher end

requested_components(::VectorMesher) = (VectorGeometry, Mesh)

function update(::PolygonMesher, m::Manager)
	mesh = m[Mesh]
	it = zip(m[PolygonGeometry], exclude=(mesh,))
	for (e_geom,) in it 
		mesh[Entity(it)] = Mesh(BasicMesh(e_geom.geometry))
	end
end

struct FunctionMesher <: Mesher end

requested_components(::FunctionMesher) = (FunctionGeometry, Mesh, Grid)

struct DensityMesher <: Mesher end

requested_components(::DensityMesher) = (DensityGeometry, Mesh, Grid)

function update(::Union{FunctionMesher, DensityMesher}, m::Manager)
	mesh = m[Mesh]
	it = zip(m[FunctionGeometry], m[Grid], exclude=(mesh,))
	for (e_geom, e_grid) in it
		points = e_grid.points
		vertices, ids = marching_cubes(e_geom.geometry, points, e_geom.iso)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
		mesh[Entity(it)] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end
end

struct FunctionColorizer <: System end

requested_components(::FunctionColorizer) = (FunctionColor, Mesh, BufferColor)

function update(::FunctionColorizer, m::Manager)
	colorbuffers = m[BufferColor]
	it = zip(m[FunctionColor], m[Mesh], exclude=(colorbuffers,))
	for (e_func, e_mesh) in it
		colorbuffers[Entity(it)] = BufferColor(e_func.color.(e_mesh.mesh.vertices))
	end
end
