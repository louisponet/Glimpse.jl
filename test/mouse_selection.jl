using Glimpse
const Gl = Glimpse
dio = Diorama(background=RGBAf0(1.0));
Gl.add_entity!(dio, separate = [Gl.Spatial(),
								Gl.Shape(),
								Gl.Material(),
								Gl.ProgramTag{Gl.PeelingInstancedProgram}(),
								Gl.UniformColor(RGBAf0(1.0,0.0,0.0,0.7)),
								Gl.Selectable()],
					shared = [Gl.PolygonGeometry(Gl.Sphere(zero(Point3f0), 1.0f0)), ])
Gl.update_system_indices!(dio)
Gl.renderloop(dio)

Gl.close(dio)

