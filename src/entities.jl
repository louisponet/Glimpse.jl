# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id
const DEFAULT_COLOR = RGBf0(0.0,0.4,0.8)
# All entity Assemblages go here

assemble_sphere(position::StaticArray{Tuple{3}} = zero(Point3f0);
	   velocity::StaticArray{Tuple{3}}       = zero(Vec3f0),
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

function assemble_wire_box(;velocity::StaticArray{Tuple{3}}= zero(Vec3f0),
	   color   ::RGB{Float32} = DEFAULT_COLOR,
       left    ::StaticArray{Tuple{3}}       = Vec3f0(-10),
       right   ::StaticArray{Tuple{3}}       = Vec3f0(10),
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
       position::StaticArray{Tuple{3}}      = zero(Point3f0),
       x::StaticArray{Tuple{3}}              = Vec3f0(1,0,0),
       y::StaticArray{Tuple{3}}              = Vec3f0(0,1,0),
       z::StaticArray{Tuple{3}}              = Vec3f0(0,0,1),
       velocity::StaticArray{Tuple{3}}       = zero(Vec3f0),
	   color   ::RGB{Float32} = DEFAULT_COLOR,
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )

    coords = (Mat3([x y z]),) .* box_coordinates()
    return (BufferColor([color for i = 1:length(coords)]),
            Spatial(position=position),
            LineOptions(linewidth, miter),
            LineGeometry(Point3f0.(coords)))
end


function assemble_box(left = Point3f0(-0.5), right=Point3f0(0.5);
	   velocity::StaticArray{Tuple{3}}       = zero(Vec3f0),
	   color   ::RGB{Float32} = DEFAULT_COLOR,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0)
       unit_direction = (right-left)/norm(right-left)

       return (Spatial((left+right)/2, velocity),
               PolygonGeometry(GeometryBasics.HyperRectangle(Vec3f0(-unit_direction/2), Vec3f0(unit_direction/2))),
               Material(specint, specpow),
               UniformColor(color),
               Shape(norm(right-left)))
end

assemble_pyramid(;position::StaticArray{Tuple{3}} = zero(Point3f0),
	   velocity  ::StaticArray{Tuple{3}}       = zero(Vec3f0),
	   color     ::RGB{Float32} = DEFAULT_COLOR,
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

assemble_file_mesh(file;position::StaticArray{Tuple{3}} = zero(Point3f0),
	   velocity::StaticArray{Tuple{3}}       = zero(Vec3f0),
	   color   ::RGB{Float32} = DEFAULT_COLOR,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       ) = (Spatial(position, velocity),
            FileGeometry(file),
            Material(specint, specpow),
            UniformColor(color),
            Shape(scale))

assemble_camera3d(width_pixels ::Int32,
			      height_pixels::Int32; eyepos   = -10*Y_AXIS,
			   					        velocity = zero(Vec3f0), kwargs...) = (Spatial(eyepos, velocity),
	   					                                                      Camera3D(width_pixels, height_pixels;
		                                                                               eyepos = eyepos, kwargs...))

function assemble_line(points::Vector{<:Point3};
                       origin = zero(Point3f0),
                       color ::RGBf0 = DEFAULT_COLOR,
                       thickness::Float32 = 2f0,
                       miter::Float32=0.6f0)

    spatial = Spatial(position=origin)
    return (spatial, UniformColor(color), LineGeometry(Point3f0.(points)), LineOptions(thickness, miter))
end


function assemble_arrow(origin::StaticArray{Tuple{3}}, extremity::StaticArray{Tuple{3}};
    color::RGBf0 = DEFAULT_COLOR,
    thickness::Float32 = 0.2f0,
    length_ratio = 0.4f0,
    radius_ratio = 2.5f0)

    spatial = Spatial(position=origin)
    direction = extremity - origin
    scale = norm(direction)
    unit_direction = direction/scale

    geom = PolygonGeometry(Arrow(zero(Point3f0), Point3f0(0, 0, scale), thickness, length_ratio, radius_ratio))
    return (spatial, geom, Rotation(rotation(Z_AXIS, Vec3f0(unit_direction))),  UniformColor(color), Material())
end

function assemble_axis_arrows(origin::StaticArray{Tuple{3}}=Point3f0(0.0);
    axis_length=5f0,
    thickness::Float32 = 0.2f0,
    length_ratio = 0.4f0,
    radius_ratio = 2.5f0)
    return (assemble_sphere(origin, radius=thickness*3, color=RGBf0(0.6, 0.6,0.6)),
            assemble_arrow(origin, origin+Point3f0(0, 0,axis_length),
                           thickness    = thickness,
                           length_ratio = length_ratio,
                           radius_ratio = radius_ratio,
                           color        = RGBf0(1,0,0)),

            assemble_arrow(origin, origin+Point3f0(0, axis_length, 0),
                           thickness    = thickness,
                           length_ratio = length_ratio,
                           radius_ratio = radius_ratio,
                           color        = RGBf0(0,1,0)),

            assemble_arrow(origin, origin+Point3f0(axis_length, 0, 0),
                           thickness    = thickness,
                           length_ratio = length_ratio,
                           radius_ratio = radius_ratio,
                           color        = RGBf0(0,0,1)))
end

function assemble_orientation_sphere(origin::StaticArray{Tuple{3}}=Point3f0(0.0);
                                     radius::Float32=5.0f0,
                                     thickness::Float32=10.0f0,
                                     base_color=RGBf0(0.7,0.7,0.7),
                                     pieces=60)

    in_plane_points     = Vector{Point3f0}(undef, pieces+2)
    
    for (i, θ) in enumerate(range(0, 2π, length=pieces))
        in_plane_points[i+1] = radius*Point3f0(cos(θ), sin(θ), 0.0)
    end
    in_plane_points[1]       = radius*Point3f0(1, 0, 0.0)

    return ((assemble_line(in_plane_points, thickness=thickness, color=0.5f0*RED, origin=origin)..., Rotation(Quaternions.qrotation(Z_AXIS, 0f0))),
            (assemble_line(in_plane_points, thickness=thickness, color=0.5f0*GREEN,origin=origin)..., Rotation(rotation(X_AXIS, Z_AXIS))),
            (assemble_line(in_plane_points, thickness=thickness, color=0.5f0*BLUE,origin=origin)..., Rotation(rotation(Y_AXIS, Z_AXIS))))

end



