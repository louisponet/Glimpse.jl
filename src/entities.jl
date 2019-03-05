component_types(e::Entity) = eltype.(e.data_ids)

# WATCHOUT FOR NOTHING
data_id(e::Entity, ::Type{T}) where {T <: ComponentData} = getfirst(x -> eltype(x) == T, e.data_ids).id

# All entity Assemblages go here

assemble_sphere(position::Point3f0,
	   velocity::Vec3f0,
	   color   ::RGBA{Float32},
       radius  ::Float32,
       specint ::Float32,
       specpow ::Float32) = (Spatial(position, velocity),
                             Geometry(AttributeMesh(Sphere(Point3f0(0.0), 1.0f0), color=color)),
                             Render{DefaultPass}(false, true, VertexArray()),
                             Material(specint, specpow, color),
                             Shape(radius))

