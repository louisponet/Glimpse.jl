using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(background=RGBAf0(1.0), interactive=true);
Gl.add_entity!(dio, separate = [Gl.Spatial(),
								Gl.Shape(),
								Gl.Material(),
								Gl.ProgramTag{Gl.InstancedPeelingProgram}(),
								Gl.UniformColor(RGBAf0(1.0,0.0,0.0,0.7)),
								Gl.Selectable()],
					shared = [Gl.PolygonGeometry(Gl.Sphere(zero(Point3f0), 1.0f0)), ])

