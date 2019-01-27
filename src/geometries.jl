import GeometryTypes: Sphere, decompose, normals


#-----------------------------Generated geometries------------------------#
function Sphere(complexity=2)
	X = .525731112f0
    Z = .850650808f0
	vertices = Point3f0[(-X,0,Z), (X,0,Z), (-X,0,-Z), (X,0,-Z),
		(0,Z,X), (0,Z,-X), (0,-Z,X), (0,-Z,-X),
		(Z,X,0), (-Z,X,0), (Z,-X,0), (-Z,-X,0)]

	faces = Face{3, Int32}[(1,4,0), (4,9,0), (4,5,9), (8,5,4), (1,8,4),
	      (1,10,8), (10,3,8), (8,3,5), (3,2,5), (3,7,2),
		(3,10,7), (10,6,7), (6,11,7), (6,0,11), (6,1,0),
		(10,1,6), (11,0,9), (2,11,9), (5,2,9), (11,2,7)]

    outverts, outfaces = subdivide(vertices, faces, complexity)
	normals = copy(outverts)
    return outverts, normals, outfaces
end

function subdivide(vertices, faces, level)
    outvertices = Point3f0[]
    outfaces    = Face{3, Int32}[]
    newfaces = Face{3, Int32}[]
    newvertices = Point3f0[]
    if level > 0
    	for face in faces
    		v1 = vertices[face[1] + 1]
    		v2 = vertices[face[2] + 1]
    		v3 = vertices[face[3] + 1]

			v4 = normalize((v1 + v2) / 2.0)
			v5 = normalize((v2 + v3) / 2.0)
			v6 = normalize((v1 + v3) / 2.0)

            vertlen = length(newvertices)
            push!(newfaces, Face{3, Int32}(vertlen, vertlen + 3, vertlen + 5))
            push!(newfaces, Face{3, Int32}(vertlen + 3, vertlen + 1, vertlen + 4))
            push!(newfaces, Face{3, Int32}(vertlen + 4, vertlen + 2, vertlen + 5))
            push!(newfaces, Face{3, Int32}(vertlen + 3, vertlen + 4, vertlen + 5))
            push!(newvertices, v1, v2, v3, v4, v5, v6)
        end
		vertices, faces = subdivide(newvertices, newfaces, level - 1)
    end
    return vertices, faces
end

function sphere(dio::Diorama, pos, radius, complexity=2, attributes_...; uniforms...)
    sphpos = convert(Point3f0, pos)
    sphrad = convert(f32, radius)
    modelmat = translmat(sphpos) * scalemat(Point3f0(sphrad,sphrad,sphrad))

    verts, norms, faces = Sphere(complexity)
    atdict = SymAnyDict(attributes_)
    unidict = SymAnyDict(uniforms)
    if haskey(unidict, :color)
        colors = fill(pop!(unidict, :color), length(verts))
    elseif haskey(atdict, :color)
        colors = pop!(atdict, :color)
    elseif haskey(atdict, :colors)
        colors = pop!(atdict, :colors)
    else
        colors = fill(RGB{f32}(0,0,0), length(verts))
    end
    unidict[:modelmat] = modelmat
    mesh = AttributeMesh((color = colors,), BasicMesh(verts, faces, norms))
    sphrend = MeshRenderable(:sphere, mesh, unidict, Dict(:default=>false))
    add!(dio, sphrend)
    return sphrend
end

#-----------------------------OBJ based geometries------------------------#

loadobj(filename::String) = load(joinpath(@__DIR__, "../../assets/obj", filename))

function cylinder(dio::Diorama, startpos, endpos, radius, name="cylinder", attributes...; uniforms...)
    startp = convert(Point3f0, startpos)
    endp   = convert(Point3f0, endpos)
    cylrad = convert(f32, radius)
    rotmat = rotate(startp, endp)
    scalm  = scalemat(Point3f0(cylrad, cylrad, norm(endp-startp)))
    tmat   = translmat(startp)

    modelmat =  tmat * rotmat * scalm

    cylmesh = loadobj("cylinder.obj")

    atdict = SymAnyDict(attributes)
    unidict = SymAnyDict(uniforms)
    if haskey(unidict, :color)
        atdict[:color] = fill(pop!(unidict, :color), length(cylmesh.vertices))
    else
        atdict[:color] = fill(RGB{f32}(0,0,0), length(cylmesh.vertices))
    end
    unidict[:modelmat] = modelmat

    cylrend = MeshRenderable(0, name, cylmesh, atdict...; unidict...)
    add!(dio, cylrend)
    return cylrend
end

function rectangle(dio::Diorama, startpos, endpos, widths, name="rectangle", attributes...; uniforms...)
    startp = convert(Point3f0, startpos)
    endp   = convert(Point3f0, endpos)
    rotmat = rotate(startp, endp)
    scalm  = scalemat(Point3f0(widths[1], widths[2], norm(endp-startp)))
    tmat   = translmat(startp)

    modelmat = tmat * rotmat * scalm

    cubmesh = loadobj("cube.obj")

    atdict = SymAnyDict(attributes)
    unidict = SymAnyDict(uniforms)
    if haskey(unidict, :color)
        atdict[:color] = fill(pop!(unidict, :color), length(cubmesh.vertices))
    else
        atdict[:color] = fill(RGB{f32}(0,0,0), length(cubmesh.vertices))
    end
    unidict[:modelmat] = modelmat
    cubrend = MeshRenderable(0, name, cubmesh, atdict...; unidict...)
    add!(dio, cubrend)
    return cubrend
end

function cone(dio::Diorama, startpos, endpos, radius, name="cone", attributes...; uniforms...)
    startp = convert(Point3f0, startpos)
    endp   = convert(Point3f0, endpos)
    cylrad = convert(f32, radius)
    rotmat = rotate(startp, endp)
    scalm  = scalemat(Point3f0(cylrad, cylrad, norm(endp-startp)))
    tmat   = translmat(startp)

    modelmat = tmat * rotmat * scalm

    cylmesh = loadobj("cone.obj")

    atdict = SymAnyDict(attributes)
    unidict = SymAnyDict(uniforms)
    if haskey(unidict, :color)
        atdict[:color] = fill(pop!(unidict, :color), length(cylmesh.vertices))
    else
        atdict[:color] = fill(RGB{f32}(0,0,0), length(cylmesh.vertices))
    end
    unidict[:modelmat] = modelmat

    cylrend = MeshRenderable(0, name, cylmesh, atdict...; unidict...)
    add!(dio, cylrend)
    return cylrend
end

function arrow(dio::Diorama, startpos, endpos, rad1, rad2, name="arrow", headratio=1/4, attributes...;uniforms...)
    startp = convert(Point3f0, startpos)
    endp   = convert(Point3f0, endpos)

    rotmat = rotate(startp, endp)
    scalm  = scalemat(Point3f0(rad1, rad1, norm(endp-startp)))
    tmat   = translmat(startp)
    modelmat = tmat * rotmat * scalm
    conemesh = loadobj("cone.obj")
    cylmesh  = loadobj("cylinder.obj")

    cyllen = norm(endp - startp) * (1-headratio)
    conelen = norm(endp - startp) * headratio

    conetrans = translmat(Point3f0(0, 0, cyllen))
    conescale = scalemat(Point3f0(rad2/rad1, rad2/rad1, conelen))
    conemat = conetrans * conescale
    coneverts = [Point3f0((conemat * Vec4f0(v[1],v[2],v[3],1.0f0))[1:3]...) for v in conemesh.vertices]
    conefaces = [v .+ Int32(length(cylmesh.vertices)+1) for v in conemesh.faces]
    allverts = Point3f0.([cylmesh.vertices;coneverts])
    allnorms = [cylmesh.normals;conemesh.normals]
    allfaces = Face{3, Int32}.([cylmesh.faces;conefaces])


    atdict = SymAnyDict(attributes)
    unidict = SymAnyDict(uniforms)
    if haskey(unidict, :color)
        atdict[:color] = fill(pop!(unidict, :color), length(allverts))
    else
        atdict[:color] = fill(RGB{f32}(0,0,0), length(allverts))
    end
    unidict[:modelmat] = modelmat
    atdict[:vertices] = allverts
    atdict[:normals] = allnorms
    atdict[:faces] = allfaces
    mesh = homogenousmesh(atdict)
    arrowrend = MeshRenderable(0, name, mesh; unidict...)
    add!(dio, arrowrend)
    return arrowrend
end
