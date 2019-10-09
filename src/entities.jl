# WATCHOUT FOR NOTHING
data_id(e::Entity, id::Int) = getfirst(x -> x.comp_id == id, e.data_ids).data_id

# All entity Assemblages go here

assemble_sphere(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       radius  ::Float32       = 1f0,
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       # tag ::ProgramTag    = ProgramTag{DefaultProgram}()
       ) = (Spatial(position, velocity),
            PolygonGeometry(Sphere(Point3f0(0.0), radius)),
            Material(specint, specpow),
            UniformColor(color),
            Shape(radius))

box_coordinates() = [zero(Point3f0), zero(Point3f0), Vec3f0(1, 0, 0),
                          Point3f0(1, 1, 0), Point3f0(0, 1, 0), zero(Point3f0),
                          Point3f0(0, 0, 1), Point3f0(1,0,1), Point3f0(1, 1, 1),
                          Point3f0(0, 1, 1), Point3f0(0, 0, 1), Point3f0(0,0,0),
                          Point3f0(1,0,0), Point3f0(1,0,1), Point3f0(1, 1, 1),
                          Point3f0(1, 1, 0), Point3f0(0,1,0), Point3f0(0, 1, 1), Point3f0(0,1,1)]

function assemble_wire_box(;velocity::Vec3f0 = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       left    ::Vec3f0        = Vec3f0(-10),
       right   ::Vec3f0        = Vec3f0(10),
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )
    coords = box_coordinates()

    return (ProgramTag{LineProgram}(),
            BufferColor([color for i = 1:length(coords)]),
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
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       linewidth::Float32      = 2f0,
       miter ::Float32         = 0.6f0,
       )

    coords = (Mat3([x y z]),) .* box_coordinates()
    return (ProgramTag{LineProgram}(),
            BufferColor([color for i = 1:length(coords)]),
            Spatial(),
            Line(linewidth, miter),
            VectorGeometry(coords))
end


assemble_box(;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       left    ::Vec3f0        = Vec3f0(-0.5),
       right   ::Vec3f0        = Vec3f0(0.5),
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       program ::RenderProgram{RP}      = RenderProgram{DefaultProgram}(GLA.Program(default_shaders()))
       ) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(HyperRectangle(left, right)),
		                                           Upload{RP}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale),
		                                           program)

assemble_pyramid(;position::Point3f0 = zero(Point3f0),
	   velocity  ::Vec3f0        = zero(Vec3f0),
	   color     ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       width     ::Float32      = 1.0f0,
       height    ::Float32      = 1.0f0,
       specint   ::Float32       = 0.8f0,
       specpow   ::Float32       = 0.8f0,
       scale     ::Float32       = 1.0f0,
       program ::RenderProgram{RP}      = RenderProgram{DefaultProgram}(GLA.Program(default_shaders()))
       ) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           PolygonGeometry(Pyramid(Point3f0(0), height, width)),
		                                           Upload{RP}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale),
		                                           program)

assemble_file_mesh(file;position::Point3f0 = zero(Point3f0),
	   velocity::Vec3f0        = zero(Vec3f0),
	   color   ::RGBA{Float32} = RGBAf0(0.0,0.4,0.8, 1.0),
       specint ::Float32       = 0.8f0,
       specpow ::Float32       = 0.8f0,
       scale   ::Float32       = 1.0f0,
       program ::RenderProgram{RP}      = RenderProgram{DefaultProgram}(GLA.Program(default_shaders()))
       ) where {RP <: RenderPassKind} = (Spatial(position, velocity),
		                                           FileGeometry(file),
		                                           Upload{RP}(false, true),
		                                           Material(specint, specpow),
		                                           UniformColor(color),
		                                           Shape(scale),
		                                           program)

assemble_camera3d(width_pixels ::Int32,
			      height_pixels::Int32; eyepos   = -10*Y_AXIS,
			   					        velocity = zero(Vec3f0), kwargs...) = (Spatial(eyepos, velocity),
	   					                                                      Camera3D(width_pixels, height_pixels;
		                                                                                eyepos = eyepos, kwargs...))

