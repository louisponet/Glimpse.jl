# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id
const DEFAULT_COLOR = RGBf0(0.0,0.4,0.8)
# All entity Assemblages go here

assemble_sphere(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   = DEFAULT_COLOR,
       radius  ::Float32       = 1f0,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       ) = (Spatial(position, velocity),
            PolygonGeometry(Sphere(Point3f0(0.0), radius)),
            Material(specint, specpow),
            (color isa ComponentData ? color : UniformColor(color)),
            Shape(radius))

box_coordinates() = [zero(Point3f0), zero(Point3f0), Vec3f0(1, 0, 0),
                          Point3f0(1, 1, 0), Point3f0(0, 1, 0), zero(Point3f0),
                          Point3f0(0, 0, 1), Point3f0(1,0,1), Point3f0(1, 1, 1),
                          Point3f0(0, 1, 1), Point3f0(0, 0, 1), Point3f0(0,0,0),
                          Point3f0(1,0,0), Point3f0(1,0,1), Point3f0(1, 1, 1),
                          Point3f0(1, 1, 0), Point3f0(0,1,0), Point3f0(0, 1, 1), Point3f0(0,1,1)]

function assemble_wire_box(;velocity::Vec3f0 = zero(Vec3f0),
	   color   ::RGBA{Float32} = DEFAULT_COLOR,
       left    ::Vec3f0        = Vec3f0(-10),
       right   ::Vec3f0        = Vec3f0(10),
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )
    coords = box_coordinates()

    return (BufferColor([color for i = 1:length(coords)]),
            Spatial(),
            LineOptions(linewidth, miter),
            LineGeometry(Point3f0.([left + ((right - left) .* c) for c in coords])))
end

function assemble_wire_axis_box(;
       position::Point3f0      = zero(Point3f0),
       x::Vec3f0               = Vec3f0(1,0,0),
       y::Vec3f0               = Vec3f0(0,1,0),
       z::Vec3f0               = Vec3f0(0,0,1),
       velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = DEFAULT_COLOR,
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )

    coords = (Mat3([x y z]),) .* box_coordinates()
    return (BufferColor([color for i = 1:length(coords)]),
            Spatial(),
            LineOptions(linewidth, miter),
            LineGeometry(Point3f0.(coords)))
end


assemble_box(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = DEFAULT_COLOR,
       left    ::Vec3f0        = Vec3f0(-0.5),
       right   ::Vec3f0        = Vec3f0(0.5),
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       )  = (Spatial(position, velocity),
             PolygonGeometry(HyperRectangle(left, right)),
             Material(specint, specpow),
             UniformColor(color),
             Shape(scale))

assemble_pyramid(;position::Point3f0 = zero(Point3f0),
	   velocity  ::Vec3f0        = zero(Vec3f0),
	   color     ::RGBA{Float32} = DEFAULT_COLOR,
       width     ::Float32      = 1.0f0,
       height    ::Float32      = 1.0f0,
       specint   ::Float32       = 0.8f0,
       specpow   ::Float32       = 0.8f0,
       scale     ::Float32       = 1.0f0,
       )= (Spatial(position, velocity),
           PolygonGeometry(Pyramid(Point3f0(0), height, width)),
           Material(specint, specpow),
           UniformColor(color),
           Shape(scale))

assemble_file_mesh(file;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = DEFAULT_COLOR,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       ) = (Spatial(position, velocity),
            FileGeometry(file),
            Material(specint, specpow),
            UniformColor(color),
            Shape(scale),
            program)

assemble_camera3d(width_pixels ::Int32,
			      height_pixels::Int32; eyepos   = -10*Y_AXIS,
			   					        velocity = zero(Vec3f0), kwargs...) = (Spatial(eyepos, velocity),
	   					                                                      Camera3D(width_pixels, height_pixels;
		                                                                                eyepos = eyepos, kwargs...))

function assemble_line(points::Vector{Point3f0};
                       color ::RGBAf0 = DEFAULT_COLOR,
                       thickness ::Float32 = 2f0,
                       miter::Float32=0.6f0)

    spatial = Spatial(position=points[1])
    return (spatial, UniformColor(color), LineGeometry(points.-(points[1],)), LineOptions(thickness, miter))
end


function assemble_arrow(origin::Point3f0, extremity::Point3f0;
    color::RGBAf0 = DEFAULT_COLOR,
    thickness::Float32 = 0.2f0,
    scale=1f0,
    length_ratio = 0.4f0,
    radius_ratio = 2.5f0)

    spatial = Spatial(position=origin)
    geom = PolygonGeometry(Arrow(zero(Point3f0), extremity- origin, thickness, length_ratio, radius_ratio))
    return (spatial, geom, UniformColor(color), Shape(scale), Material())
end

#TODO could clean this up a little
function assemble_axis_arrows(origin::Point3f0=Point3f0(0.0);
    axis_length=5f0,
    thickness::Float32 = 0.2f0,
    scale=1f0,
    length_ratio = 0.4f0,
    radius_ratio = 2.5f0)

    spatial = Spatial(position=origin)
    shape = Shape(scale)
    material = Material()

    sph_geom = PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0))
    geom1 = PolygonGeometry(Arrow(zero(Point3f0), Point3f0(0, 0, axis_length), thickness, length_ratio, radius_ratio))
    geom2 = PolygonGeometry(Arrow(zero(Point3f0), Point3f0(0, axis_length, 0), thickness, length_ratio, radius_ratio))
    geom3 = PolygonGeometry(Arrow(zero(Point3f0), Point3f0(axis_length, 0, 0), thickness, length_ratio, radius_ratio))

    c1 = UniformColor(RGBA(1, 0, 0, 0.8))
    c2 = UniformColor(RGBA(0, 1, 0, 0.8))
    c3 = UniformColor(RGBA(0, 0, 1, 0.8))
    c_sph = UniformColor(RGBA(0.6, 0.6, 0.6, 1.0))

    return ((spatial, sph_geom, c_sph, Shape(thickness*3), material),
            (spatial, geom1, c1, shape, material),
            (spatial, geom2, c2, shape, material),
            (spatial, geom3, c3, shape, material))
end







