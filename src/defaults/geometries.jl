import GeometryTypes: Sphere, decompose, normals, sphere

function sphere(dio::Diorama, pos, radius, name=:sphere, attributes...; uniforms...)
    sphpos = convert(Point3f0, pos)
    sphrad = convert(f32, radius)

    sphere  = Sphere{f32}(sphpos, sphrad)
    verts   = decompose(Point3f0, sphere)
    faces   = decompose(GLTriangle, sphere)
    norms = normals(verts, faces)

    atdict = SymAnyDict(attributes)
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
    sphrend = Renderable(0, name, :vertices => verts, :faces=> faces, :normals => norms, :color => colors, atdict...; unidict...)
    add!(dio, sphrend)
    return sphrend
end
