# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id

# All entity Assemblages go here

assemble_sphere(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       radius  ::Float32       = 1f0,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       renderpass::Type{RP} = DefaultPass) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0)),
		                                           Upload{renderpass}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(radius))
assemble_box(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       left    ::Vec3f0        = Vec3f0(-0.5),
       right   ::Vec3f0        = Vec3f0(0.5),
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       renderpass::Type{RP}            = DefaultPass) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(HyperRectangle(left, right)),
		                                           Upload{renderpass}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale))

assemble_pyramid(;position::Point3f0 = zero(Point3f0),
	   velocity  ::Vec3f0        = zero(Vec3f0),
	   color     ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       width     ::Float32      = 1.0f0,
       height    ::Float32      = 1.0f0,
       specint   ::Float32       = 0.8f0,
       specpow   ::Float32       = 0.8f0,
       scale     ::Float32       = 1.0f0,
       renderpass::Type{RP}            = DefaultPass) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(Pyramid(Point3f0(0), height, width)),
		                                           Upload{renderpass}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale))

assemble_file_mesh(file;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       renderpass::Type{RP}            = DefaultPass) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           FileGeometry(file),
		                                           Upload{renderpass}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale))

assemble_camera3d(eyepos  ::Point3f0,
				  velocity::Vec3f0,
				  args...) = (Spatial(eyepos, velocity),
				              Camera3D(eyepos, args...))

