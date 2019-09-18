using Glimpse
const Gl = Glimpse
Entity(dio, Gl.Spatial(),
								Gl.Shape(),
								Gl.Material(),
								Gl.ProgramTag{Gl.InstancedPeelingProgram}(),
								Gl.UniformColor(RGBAf0(1.0,0.0,0.0,0.7)),
								Gl.Selectable(),
					Gl.PolygonGeometry(Gl.Sphere(zero(Point3f0), 1.0f0)))

