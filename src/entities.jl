data_id(e::Entity, component::Symbol) = e.data_ids[component]

# All entity Assemblages go here

SphereData(position::Point3f0,
		   velocity::Vec3f0,
		   color   ::RGBA{Float32},
   	       radius  ::Float32,
           specint ::Float32,
           specpow ::Float32) = (spatial  = SpatialData(position, velocity),
                                 geometry = GeometryData(AttributeMesh(Sphere(Point3f0(0.0), radius), color=color)),
                                 render   = RenderData(false, true, [:default], [false], VertexArray[]),
                                 material = MaterialData(specint, specpow))

