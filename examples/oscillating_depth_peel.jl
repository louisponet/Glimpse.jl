#%%
# This example is basically the same as the instanced_depth peel but now we are also adding an osscilation system to it.
using Glimpse
const Gl = Glimpse
begin
dio = Diorama(background=RGBAf0(0.0,0.0,0.0,1.0));
Gl.insert_system_before!(dio, Gl.UniformCalculator, Gl.oscillator_system(dio))
Gl.add_shared_component!(dio, Gl.Spring)
spherepoint(r, theta, phi) = r*Point3f0(sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta))
nspheres = 2000
radii    = Iterators.cycle(range(1f0, 200f0, length=div(nspheres,40)))
angs     = Iterators.cycle(range(0, 2pi, length =div(nspheres, 40)))
angs2    = Iterators.cycle(range(-pi, pi, length=div(nspheres, 60)))

ps       = [spherepoint(r, a1, a2) for (r, a1, a2, i) in zip(radii, angs, angs2, 1:nspheres)]
progtag  = Gl.ProgramTag{Gl.PeelingInstancedProgram}()
cs = [RGBAf0(0.1, 0.5, 0.9, 0.4), RGBAf0(0.9,0.1,0.5, 0.4)]
sph_geom = Gl.PolygonGeometry(Gl.Sphere(Point3f0(0.0), 1f0))
spring   = Gl.Spring()
for i = 1:nspheres
	color = cs[mod1(i, 2)] 
	Gl.new_entity!(dio, separate=[Gl.Spatial(position=ps[i]),
	                              Gl.Material(),
	                              Gl.Shape(),
	                              Gl.UniformColor(color),
	                              Gl.Dynamic(),
	                              progtag], shared=Gl.ComponentData[sph_geom, spring]);
end

Gl.update_system_indices!(dio)
Gl.renderloop(dio)
end
#%%
