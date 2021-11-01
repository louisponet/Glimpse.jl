#%%
using Glimpse
const Gl = Glimpse
import Glimpse: SystemKind, System, Component, ComponentData, update, Spatial, TimingData,
                valid_entities, singleton, component, RGBAf0
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
    rotation = component(sys, Rotation)
    spatial  = component(sys, Spatial)
    dt       = Float32(singleton(sys, TimingData).dtime)
    for i in valid_entities(rotation, spatial)
        e_rotation = rotation[i]
        n          = e_rotation.axis
        r          = -e_rotation.center + spatial[i].position
        theta      = e_rotation.omega * dt
        nnd        = n * dot(n, r)
        spatial[i] = Spatial(Point3f0(e_rotation.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)), spatial[i].velocity)
    end
end

begin
    dio = Diorama(; background = RGBAf0(0.0, 0.0, 0.0, 1.0))

    # add new component and system to the diorama, alongside with the already present rendering systems/components
    Gl.add_component!(dio, Rotation)
    Gl.add_system!(dio, rotator_system(dio))
    # add some sphere entities and the new extra component which will automatically engage with the new system
    geom = Gl.PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0))
    progtag = Gl.ProgramTag{Gl.PeelingProgram}()
    for i in 1:2000
        Gl.new_entity!(dio;
                       separate = [Gl.UniformColor(rand(RGBAf0)),
                                   Gl.Spatial(50 * (1 .- rand(Point3f0)), rand(Vec3f0)),
                                   Gl.Material(), Gl.Shape(),
                                   Rotation(0.2f0, 50 * (1 .- rand(Point3f0)),
                                            normalize(1 .- rand(Vec3f0))), Gl.Dynamic(),
                                   progtag], shared = [geom])
    end
    dio.loop = @async Gl.renderloop(dio)
end
#%%
