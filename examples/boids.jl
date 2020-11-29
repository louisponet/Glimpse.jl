#%%
using Revise
using Glimpse
const Gl = Glimpse
using Glimpse: Spatial, Line, BufferColor, LineGeometry, VectorGeometry
using NearestNeighbors
using StaticArrays
const COMPONENTDATA_TYPES = copy(Gl.COMPONENTDATA_TYPES)
@component_with_kw struct WallPlane <: ComponentData
    w1::Vec3{Float64} = Vec3(1.0,0.0,0.0)
    w2::Vec3{Float64} = Vec3(0.0,1.0,0.0)
    normal::Vec3{Float64} = normalize(cross(w1, w2)) 
end
function cube_planes(dio, origin, right)
    r = right - origin
    widths = (Vec3(abs(r[1]),0.0,0.0),
              Vec3(0.0, abs(r[2]),0.0),
              Vec3(0.0, 0.0, abs(r[3])))
    heights = (Vec3(0.0,abs(r[2]),0.0),
              Vec3(0.0, 0.0,abs(r[3])),
              Vec3(abs(r[1]), 0.0, 0.0))

    for (w,h) in zip(widths, heights)
        Entity(dio, WallPlane(w1=w, w2=h), Spatial(position=origin))
        Entity(dio, WallPlane(w1=-w, w2=-h), Spatial(position=right))
    end
	Entity(dio, Gl.assemble_wire_box(left=Vec3f0(origin), right=Vec3f0(right))...)
end


struct WallBouncer <: System end
Overseer.requested_components(::WallBouncer) = (Spatial, WallPlane)

function Gl.update(::WallBouncer, m::Diorama)
    spat = m[Spatial]
    wp   = m[WallPlane]
    dt   = m[Gl.TimingData][1].dtime
    for we in @entities_in(spat && wp)
        n = wp[we].normal
        w1 = wp[we].w1
        w2 = wp[we].w2
        origin = spat[we].position
        for e in @entities_in(m[Spatial] && !wp)
            Threads.@spawn begin
            e_spat = spat[e]
            if !isapprox(dot(n, e_spat.velocity), 0)
                p0 = e_spat.position
                pr = dt * e_spat.velocity
                t = dot(-p0 + origin, n)/dot(pr,n)
                if 0 <= t <= 2.0
                    int_p = p0 + t*pr
                    if 0 <= dot(int_p - origin, normalize(w1)) <= norm(w1) && 0<=dot(int_p - origin, normalize(w2)) <= norm(w2)
                        spat[e] = Spatial(e_spat.position, e_spat.velocity-2n*dot(n,e_spat.velocity))
                    end
                end
            end
        end
        end
    end
    push!(m[Gl.UpdatedComponents][1], Spatial)
end

struct VelocityDrawer <: System end
Overseer.requested_components(::VelocityDrawer) = (Spatial, Gl.UniformColor)

function Gl.update(::VelocityDrawer, m::Diorama)
    spat = m[Spatial]
    geom = m[VectorGeometry]
    ucolor = m[Gl.UniformColor]
    r = [0;range(0,0.7,length=3)]
    for e in @entities_in(spat && geom)
        e = Entity(it)
        if norm(s.velocity) != 0.0
            geom[e] = LineGeometry([Point3f0(s.velocity*i) for i in r])
        end
    end
end

@component struct Boid end

struct Boids <: System end
Overseer.requested_components(::Boids) = (Boid,)
#%%
function Gl.update(::Boids, m::Diorama)
    spat = m[Spatial]
    dt = m[Gl.TimingData][1].dtime
    geom = m[Gl.PolygonGeometry]
    boid = m[Boid]
    it = @entities_in(spat && boid)
    points = map(e->spat[e].position, it)
    tree = KDTree(points; leafsize=10)
    wp = m[WallPlane]
    for e in @entities_in(spat && boid)
        Threads.@spawn begin
        s1 = spat[e]
        prev_v = norm(s1.velocity)
        added_v = zero(Vec3f0)
        avg_pos = zero(Point3f0)
        avg_v   = zero(Vec3f0)
        ids = inrange(tree, s1.position, 7, false)
        tot = length(ids)
        for id in ids
            s2 = spat[it[id]]
            r = s1.position - s2.position
            if norm(r) < 1
                added_v += r
            end
            avg_pos += s2.position
            avg_v   += s2.velocity
        end
        if tot != 0
            added_v += (avg_pos/tot - s1.position)/200 + (avg_v/tot - s1.velocity)/20
        end
        spat[e] = Spatial(s1.position, normalize(s1.velocity + added_v)*prev_v)
    end
    end
end

dio = Gl.Diorama(Stage(:boids, [Boids(), WallBouncer(), VelocityDrawer()]), background=RGBAf0(0.0,0.0,0.0,1.0));
cube_planes(dio, Vec3(-60.0), Vec3(60.0))
expose(dio);
for i = -1000:1000
    t = Entity(dio, Gl.assemble_sphere(Point3f0(10*(0.5-rand(Point3f0))), velocity=8*normalize(0.5f0-rand(Vec3f0)), radius=0.5f0)..., Gl.LineOptions(),Gl.Spring(k=0.00001), Boid())
end
empty!(dio)
#%%
Gl.glfw_destroy_current_context()

using BenchmarkTools
@btime Gl.update(Boids(), $(dio.manager))
using StaticArrays
Point3f0 <: SVector
supertype(Point3f0)
