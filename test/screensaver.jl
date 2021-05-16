using Glimpse
const Gl = Glimpse
import Glimpse:  System, Component, ComponentData, Spatial, TimingData, valid_entities, RGBAf0
using LinearAlgebra

# define rotation component and system
# add new component and system to the diorama, alongside with the already present rendering systems/components
push_system(dio, Gl.Rotator());
# add some sphere entities and the new extra component which will automatically engage with the new system
geom = Gl.PolygonGeometry(Sphere(Point3f0(0.0), 1.0f0))
progtag = Gl.ProgramTag{Gl.PeelingProgram}()
for i = 1:2
    Entity(dio, Gl.UniformColor(rand(RGBAf0)),
                                  Gl.Spatial(50*(1 .- rand(Point3f0)), rand(Vec3f0)),
                                  Gl.Material(),
                                  Gl.Shape(),
                                  Gl.Rotation(0.2f0, 50*(1 .- rand(Point3f0)), normalize(1 .- rand(Vec3f0))),
                                  Gl.Dynamic(),
                                  progtag,
                        geom)
end
