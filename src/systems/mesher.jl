
# This system constructs all the meshes from geometries. These meshes will then be used to be uploaded to OpenGL 
struct Mesher <: System
	data ::SystemData

	Mesher(dio::Diorama) = new(SystemData(dio, (Geometry, Color, Mesh, Grid), ()))
end

function update_indices!(sys::Mesher)
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)
	meshed_entities  = valid_entities(mesh)
	funcgeometry     = comp(FunctionGeometry)
	densgeometry     = comp(DensityGeometry)
	grid             = scomp(Grid)
	vgeom            = comp(VectorGeometry)
	# cycledcolor   = comp(CycledColor)
	tids = Vector{Int}[]
	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file, vgeom), (spolygon, sfile)))
		for com in geomcomps
			push!(tids, setdiff(valid_entities(com), valid_entities(meshcomp)))
		end
	end
	sys.data.indices = [tids; [setdiff(valid_entities(funcgeometry, grid), meshed_entities),
	                           setdiff(valid_entities(densgeometry, grid), meshed_entities)]]
 end

function update(sys::Mesher)
	if all(isempty.(indices(sys)))
		return
	end
	comp(T)  = component(sys, T)
	scomp(T) = shared_component(sys, T)
	#setup separate meshes
	polygon  = comp(PolygonGeometry)
	file     = comp(FileGeometry)
	mesh     = comp(Mesh)
	
	spolygon = scomp(PolygonGeometry)
	sfile    = scomp(FileGeometry)
	smesh    = scomp(Mesh)

	vgeom    = comp(VectorGeometry)
	id_counter = 1
	for (meshcomp, geomcomps) in zip((mesh, smesh), ((polygon, file, vgeom), (spolygon, sfile)))
		for com in geomcomps
			for e in indices(sys)[id_counter]
				meshcomp[e] = Mesh(BasicMesh(com[e].geometry))
			end
			id_counter += 1
		end
	end

	funcgeometry  = comp(FunctionGeometry)
	densgeometry  = comp(DensityGeometry)
	grid          = scomp(Grid)
	funccolor     = comp(FunctionColor)
	denscolor     = comp(DensityColor)
	# cycledcolor   = comp(CycledColor)
	colorbuffers  = comp(BufferColor)

	function calc_mesh(density, iso, e)
		vertices, ids = marching_cubes(density, grid[e].points, iso)
		faces         = [Face{3, GLint}(i,i+1,i+2) for i=1:3:length(vertices)]
		# if has_entity(cycledcolor, e)
		if has_entity(funccolor, e)
			colorbuffers[e] = BufferColor(funccolor[e].color.(vertices))
		elseif has_entity(denscolor, e)
			colorbuffers[e] = BufferColor([denscolor[e].color[i...] for i in ids])
		end
		mesh[e] = Mesh(BasicMesh(vertices, faces, normals(vertices, faces)))
	end

	for e in indices(sys)[id_counter] 
		values        = funcgeometry[e].geometry.(grid[e].points)
		calc_mesh(values, funcgeometry[e].iso, e)
		id_counter += 1
	end

	for e in indices(sys)[id_counter]
		calc_mesh(densgeometry[e].geometry, densgeometry[e].iso, e)
	end
end

