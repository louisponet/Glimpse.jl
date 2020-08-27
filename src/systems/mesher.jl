
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
	if iterate(it) === nothing
    	return
	end
	geometries_handled = geometry_type(M)[]
	u_geoms = Iterators.unique(geom.data)
	meshes = [Mesh(BasicMesh(g.geometry)) for g in u_geoms]
	prevlen = length(mesh.shared)
    append!(mesh.shared, meshes)
	for e in it
    	egeom = geom[e]
    	push!(mesh.indices, e.id)
    	push!(mesh.data, prevlen + findfirst(x -> x == egeom, u_geoms))
	end
end

struct FunctionMesher <: Mesher end

Overseer.requested_components(::FunctionMesher) = (FunctionGeometry, Mesh, Grid)

struct DensityMesher <: Mesher end

Overseer.requested_components(::DensityMesher) = (DensityGeometry, Mesh, Grid)

function Overseer.update(::Union{FunctionMesher, DensityMesher}, m::AbstractLedger)
	mesh = m[Mesh]
	grid = m[Grid]
	for geom in (m[FunctionGeometry], m[DensityGeometry])
    	for e in @entities_in(geom && grid && !mesh)
    		points = grid[e].points
    		vertices, ids = marching_cubes(geom[e].geometry, points, geom[e].iso)
    		faces         = [GeometryBasics.TriangleFace{GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
    		norms =  length(faces) == 0 ? Vec3f0[] : normals(vertices, faces) 
    		mesh[e] = Mesh(BasicMesh(vertices, faces, norms))
    	end
	end
end

struct FunctionColorizer <: System end

Overseer.requested_components(::FunctionColorizer) = (FunctionColor, Mesh, BufferColor)

function Overseer.update(::FunctionColorizer, m::AbstractLedger)
	colorbuffers = m[BufferColor]
	fcolor       = m[FunctionColor]
	mesh         = m[Mesh]
	for e in @entities_in(fcolor && mesh && !colorbuffers)
		colorbuffers[e] = BufferColor(fcolor[e].color.(mesh[e].mesh.vertices))
	end
end
