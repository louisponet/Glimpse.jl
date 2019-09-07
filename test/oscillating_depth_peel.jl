using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(background=RGBAf0(0.0,0.0,0.0,1.0), interactive=true);
Gl.add_shared_component!(dio, Gl.Spring)
Gl.insert_system_before!(dio, Gl.UniformCalculator, Gl.Oscillator(dio))
spherepoint(r, theta, phi) = r*Point3f0(sin(theta)*cos(phi), sin(theta)*sin(phi), cos(theta))
nspheres = 2
radii    = Iterators.cycle(range(1f0, 200f0, length=div(nspheres,1)))
angs     = Iterators.cycle(range(0, 2pi, length =div(nspheres, 1)))
angs2    = Iterators.cycle(range(-pi, pi, length=div(nspheres, 1)))

ps       = [spherepoint(r, a1, a2) for (r, a1, a2, i) in zip(radii, angs, angs2, 1:nspheres)]
progtag  = Gl.ProgramTag{Gl.PeelingInstancedProgram}()
cs = [RGBAf0(0.1, 0.5, 0.9, 0.4), RGBAf0(0.9,0.1,0.5, 0.4)]
sph_geom = Gl.PolygonGeometry(Gl.Sphere(Point3f0(0.0), 1f0))
spring   = Gl.Spring()
for i = 1:nspheres
	color = cs[mod1(i, 2)] 
	Gl.add_entity!(dio, separate=[Gl.Spatial(position=ps[i]),
	                              Gl.Material(),
	                              Gl.Shape(),
	                              Gl.UniformColor(color),
	                              Gl.Dynamic(),
	                              Gl.Selectable(),
	                              progtag], shared=Gl.ComponentData[sph_geom, spring]);
end
