#%%
using Revise
using Glimpse
const Gl = Glimpse
#%%

dio = Diorama(background=RGBAf0(1.0));
# Gl.add_entity!(dio, separate = [Gl.Spatial(), Gl.PolygonGeometry(Gl.Sphere(zero(Point3f0), 1.0f0)), Gl.Selectable()])
Gl.add_entity!(dio, separate = [Gl.Spatial(),
								Gl.Shape(),
								Gl.Material(),
								Gl.PolygonGeometry(Gl.Sphere(zero(Point3f0), 1.0f0)),
								Gl.Selectable(),
								Gl.ProgramTag{Gl.DefaultProgram}(),
								Gl.UniformColor(RGBAf0(1.0,0.0,0.0,1.0))])
Gl.update_system_indices!(dio)
Gl.renderloop(dio)

Gl.component(dio, Gl.AABB).data

Gl.close(dio)
#%%
Gl.GLFW.Terminate()
Gl.GLFW.Init()
#%%
