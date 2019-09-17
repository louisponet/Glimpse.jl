using Glimpse
const Gl = Glimpse
import Glimpse:  System, Component, ComponentData, Spatial, TimingData, valid_entities, singleton, component, RGBAf0
using LinearAlgebra

# define rotation component and system
struct Rotation <: ComponentData
	omega::Float32
	center::Point3f0
	axis::Vec3f0
end

struct Rotator <: System  end
Gl.ECS.requested_components(::Rotator) = (Spatial, Rotation, TimingData)

function Gl.ECS.update(::Rotator, dio::Manager)
	rotation  = dio[Rotation]
	spatial   = dio[Spatial]
	dt        = Float32(dio[TimingData][1].dtime)
	for (e_rotation, (i, e_spatial)) in zip(rotation, enumerate(spatial))
		n          = e_rotation.axis
		r          = - e_rotation.center + e_spatial.position
		theta      = e_rotation.omega * dt
		nnd        = n * dot(n, r)
		spatial[i] = Spatial(Point3f0(e_rotation.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)), e_spatial.velocity)
	end
end

dio = Gl.Diorama(background=RGBAf0(0.0,0.0,0.0,1.0), interactive=true);
# add new component and system to the diorama, alongside with the already present rendering systems/components
push_system(dio, Rotator());
# add some sphere entities and the new extra component which will automatically engage with the new system
geom = Gl.PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0))
progtag = Gl.ProgramTag{Gl.PeelingProgram}()
for i = 1:2
	Entity(dio, Gl.UniformColor(rand(RGBAf0)),
	                              Gl.Spatial(50*(1 .- rand(Point3f0)), rand(Vec3f0)),
	                              Gl.Material(),
	                              Gl.Shape(),
	                              Rotation(0.2f0, 50*(1 .- rand(Point3f0)), normalize(1 .- rand(Vec3f0))),
	                              Gl.Dynamic(),
	                              progtag,
                        geom)
end
