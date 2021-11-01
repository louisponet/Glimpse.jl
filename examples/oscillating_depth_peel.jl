# This example is basically the same as the instanced_depth peel but now we are also adding an osscilation system to it.
#%%
using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(; background = RGBAf0(0.0, 0.0, 0.0, 1.0));
function spherepoint(r, theta, phi)
    return r * Point3f0(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))
end
nspheres = 20000
radii = Iterators.cycle(range(1.0f0, 200.0f0; length = div(nspheres, 40)))
angs = Iterators.cycle(range(0, 2pi; length = div(nspheres, 40)))
angs2 = Iterators.cycle(range(-pi, pi; length = div(nspheres, 60)))

ps       = [spherepoint(r, a1, a2) for (r, a1, a2, i) in zip(radii, angs, angs2, 1:nspheres)]
progtag  = Gl.ProgramTag{Gl.InstancedPeelingProgram}()
cs       = [RGBAf0(0.1, 0.5, 0.9, 0.4), RGBAf0(0.9, 0.1, 0.5, 0.4)]
sph_geom = Gl.PolygonGeometry(Gl.Sphere(Point3f0(0.0), 1.0f0))
spring   = Gl.Spring()
for i in 1:nspheres
    color = cs[mod1(i, 2)]
    Entity(dio, Gl.Spatial(; position = ps[i]), Gl.Material(), Gl.Shape(),
           Gl.UniformColor(color), Gl.Dynamic(), Gl.Selectable(), progtag, sph_geom, spring)
end

Gl.renderloop(dio)
#%%
