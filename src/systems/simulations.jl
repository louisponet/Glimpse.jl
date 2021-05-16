abstract type SimulationSystem <: System end

@component @with_kw struct Spring
    center::Point3f0 = zero(Point3f0)
    k     ::Float32  = 0.01f0
    damping::Float32 = 0.0001f0
end

struct Oscillator <: System end


Overseer.requested_components(::Oscillator) = (Spatial, Spring, UpdatedComponents, TimingData)

function Overseer.update(::Oscillator, m::AbstractLedger)
    td     = m[TimingData][1] 
    dt     = td.dtime
    @inbounds for e in @entities_in(m, Spatial && Spring)
        new_v   = e.velocity - (e.position - e.center) * e.k - e.velocity * e.damping
        e[Spatial] = Spatial(e.position, new_v)
    end
    register_update(m, Spatial)
end

@component struct Orbit
    omega::Float32
    center::Point3f0
    axis::Vec3f0
end

struct Rotator <: System  end
Overseer.requested_components(::Rotator) = (Spatial, Orbit, TimingData)

function Overseer.update(::Rotator, m::AbstractLedger)
    dt = m[TimingData][1].dtime
    @inbounds for e in @entities_in(m, Rotation && Spatial) 
        n          = e.axis
        r          = - e.center + e.position
        theta      = e.omega * dt
        nnd        = n * dot(n, r)
        e[Spatial] = Spatial(Point3f0(e.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)), e.velocity)
    end
    register_update(m, Spatial)
end
struct Mover <: System end

Overseer.requested_components(::Mover) = (Spatial, TimingData)

function Overseer.update(::Mover, m::AbstractLedger)
    dt = m[TimingData][1].dtime
    for e in @entities_in(m, Spatial)
        e[Spatial] = Spatial(e.position + e.velocity * dt, e.velocity)
    end
    register_update(m, Spatial)
end



