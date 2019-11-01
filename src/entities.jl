# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id
const DEFAULT_COLOR = RGBAf0(0.0,0.4,0.8, 1.0)
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
            Line(linewidth, miter),
            VectorGeometry([left + ((right - left) .* c) for c in coords]))
end

function assemble_wire_axis_box(;
       position::Point3f0      = zero(Point3f0),
       x::Vec3f0               = Vec3f0(1,0,0),
       y::Vec3f0               = Vec3f0(0,1,0),
       z::Vec3f0               = Vec3f0(0,1,0),
       velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = DEFAULT_COLOR,
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )

    coords = (Mat3([x y z]),) .* box_coordinates()
    return (BufferColor([color for i = 1:length(coords)]),
            Spatial(),
            Line(linewidth, miter),
            VectorGeometry(coords))
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






