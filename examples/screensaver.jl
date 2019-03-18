#%%
using Glimpse
const Gl = Glimpse
import Glimpse: SystemKind, System, Component, ComponentData, update, Spatial, TimingData, ranges
using LinearAlgebra

# define rotation component and system
struct Rotation <: ComponentData
	omega::Float32
	center::Point3f0
	axis::Vec3f0
end
RotationComponent(id) = Component(id, Rotation)

struct Rotator <: SystemKind end
rotator_system(dio) = System{Rotator}(dio, (Spatial, Rotation), (TimingData,))

function update(sys::System{Rotator})
	rotation  = sys[Rotation].data
	spatial   = sys[Spatial].data
	dt        = Float32(sys[TimingData].dtime)
	for ids in ranges(rotation, spatial), i in ids
		e_rotation = rotation[i]
		n          = e_rotation.axis
		r          = - e_rotation.center + spatial[i].position
		theta      = e_rotation.omega * dt
		nnd        = n * dot(n, r)
		spatial[i] = Spatial(Point3f0(e_rotation.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)),
							 spatial[i].velocity)
	end
end

dio = Diorama(:Glimpse, Screen(:default, (1260,720)));

# add new component and system to the diorama, alongside with the already present rendering systems/components
Gl.add_component!(dio, Rotation);
Gl.add_system!(dio, rotator_system(dio));
# add some sphere entities and the new extra component which will automatically engage with the new system
for i = 1:2000
	Gl.new_entity!(dio, Gl.assemble_sphere(50*(1 .- rand(Point3f0)), rand(Vec3f0), rand(RGBA{Float32}), 1.0f0, 0.8f0, 0.8f0)...);
	Gl.set_entity_component!(dio, i, Rotation(1f0, 50*(1 .- rand(Point3f0)), normalize(1 .- rand(Vec3f0))))
end
# add the some light and camera entities to actually see some stuff
Gl.new_entity!(dio, Gl.PointLight(Point3f0(200.0), 0.5f0, 0.5f0, 0.5f0, RGBA{Float32}(1.0))); 
camid = Gl.new_entity!(dio, Gl.assemble_camera3d(Point3f0(Gl.perspective_defaults()[:eyepos]), Vec3f0(0))...)

# one can even rotate the camera itself!
Gl.set_entity_component!(dio, camid, Rotation(1f0, 50*(1 .- rand(Point3f0)), normalize(1 .- rand(Vec3f0))))
#%%


