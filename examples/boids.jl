#%%
using Glimpse
using Glimpse.Parameters
import Glimpse: ComponentData, System, requested_components, Spatial, Line, LineProgram, BufferColor, VectorGeometry, Mesh
const Gl = Glimpse
import Glimpse.ECS: AbstractManager, pointer_zip

@with_kw struct WallPlane <: ComponentData
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
Gl.ECS.requested_components(::WallBouncer) = (Spatial, WallPlane)

function Gl.update(::WallBouncer, m::AbstractManager)
    spat = m[Spatial]
    wp   = m[WallPlane]
    dt   = m[Gl.TimingData][1].dtime
    for (wall_spat, wall_plane) in zip(spat, wp)
        n = wall_plane.normal
        w1 = wall_plane.w1
        w2 = wall_plane.w2
        origin = wall_spat.position
        for (spat_ptr,) in pointer_zip(m[Spatial], exclude=(wp,))
            e_spat = unsafe_load(spat_ptr)
            isapprox(dot(n, e_spat.velocity), 0) && continue
            p0 = e_spat.position
            pr = dt * e_spat.velocity
            t = dot(-p0 + origin, n)/dot(pr,n)
            if 0 <= t <= 2.0
                int_p = p0 + t*pr
                if 0 <= dot(int_p - origin, normalize(w1)) <= norm(w1) && 0<=dot(int_p - origin, normalize(w2)) <= norm(w2)
                    unsafe_store!(spat_ptr, Spatial(e_spat.position, e_spat.velocity-2n*dot(n,e_spat.velocity)))
                end
            end
        end
    end
    push!(m[Gl.UpdatedComponents][1], Spatial)
end

struct VelocityDrawer <: System end
Gl.ECS.requested_components(::VelocityDrawer) = (Spatial, Gl.UniformColor, Line, BufferColor, VectorGeometry, Mesh, Gl.ProgramTag{Gl.LineProgram})

function Gl.update(::VelocityDrawer, m::AbstractManager)
    spat = m[Spatial]
    line = m[Line]
    geom = m[VectorGeometry]
    ucolor = m[Gl.UniformColor]
    vao = m[Gl.Vao{Gl.LineProgram}]
    prog = m[Gl.RenderProgram{Gl.LineProgram}][1].program
    r = [0;range(0,0.7,length=3)]
    it = zip(spat, ucolor)
    for (s, uc) in it
        e = Entity(it)
        if norm(s.velocity) != 0.0
            c_buff = [RGBAf0(1.0, .5,.5,1.0) for i=1:length(r)]
            if !in(e, vao)
                v_buff = [Point3f0(s.velocity*i) for i in r]
        		buffers = [Gl.generate_buffers(prog, Gl.BasicMesh(v_buff));
                           Gl.generate_buffers(prog, Gl.GEOMETRY_DIVISOR, color=c_buff)]
                vao[e] = Gl.Vao{Gl.LineProgram}(Gl.VertexArray(buffers, 11), true)
            else
                v_buff = [Point3f0(s.velocity * i) for i in r]
                e_vao = vao[e]
                v_binfo = Gl.GLA.bufferinfo(e_vao.vertexarray, :vertices)
                Gl.GLA.reupload_buffer_data!(v_binfo.buffer, v_buff)
            end
            line[e] = Line()
        end
    end
end

struct Boids <: System end

function Gl.update(::Boids, m::AbstractManager)
    spat = m[Spatial]
    dt = m[Gl.TimingData][1].dtime
    it = zip(m[Spatial], m[Gl.PolygonGeometry])
    for (s1, df) in it
        e1 = Entity(it)
        prev_v = norm(s1.velocity)
        added_v = zero(Vec3f0)
        avg_pos = zero(Point3f0)
        avg_v   = zero(Vec3f0)
        tot = 0
        for (s2, dfa) in it
            e2 = Entity(it)
            e1 == e2 && continue
            r = s1.position - s2.position
            norm(r) > 7 && continue
            if norm(r) < 1
                added_v += r
            end
            avg_pos += s2.position
            avg_v   += s2.velocity
            tot += 1
        end
        if tot != 0
            added_v += (avg_pos/tot - s1.position)/400 + (avg_v/tot - s1.velocity)/20
        end
        spat[e1] = Spatial(s1.position, normalize(s1.velocity + added_v+0.1(0.5f0-rand(Vec3f0)))*prev_v)
    end
end

dio = Gl.Diorama(Boids(), WallBouncer(), VelocityDrawer(), background=RGBAf0(0.0,0.0,0.0,1.0));
cube_planes(dio, Vec3(-20.0), Vec3(20.0))

Gl.renderloop(dio)
for i = -200:200
    t = Entity(dio, Gl.assemble_sphere(position=Point3f0(10*(0.5-rand(Point3f0))), velocity=8*normalize(0.5f0-rand(Vec3f0)), radius=0.5f0)...)
end
#%%
