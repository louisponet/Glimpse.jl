abstract type SimulationSystem <: System end

@component @with_kw struct Spring
	center::Point3f0 = zero(Point3f0)
	k     ::Float32  = 0.01f0
	damping::Float32 = 0.0001f0
end

struct Oscillator <: System end


Overseer.requested_components(::Oscillator) = (Spatial, Spring, UpdatedComponents, TimingData)

function Overseer.update(::Oscillator, m::AbstractLedger)
	spat, spring=m[Spatial], m[Spring]
	td     = m[TimingData][1] 
	dt     = td.dtime

	it = @entities_in(spat && spring)
	@inbounds for e in it
		e_spat  = spat[e]
		spr     = spring[e]
		v_prev  = e_spat.velocity 
		new_v   = v_prev - (e_spat.position - spr.center) * spr.k - v_prev * spr.damping
		spat[e] = Spatial(e_spat.position, new_v)
	end
	push!(m[UpdatedComponents][1].components, Spatial)
end

@component struct Orbit
	omega::Float32
	center::Point3f0
	axis::Vec3f0
end

struct Rotator <: System  end
Overseer.requested_components(::Rotator) = (Spatial, Orbit, TimingData)

function Overseer.update(::Rotator, dio::AbstractLedger)
	rotation  = dio[Orbit]
	spatial   = dio[Spatial]
	dt        = Float32(dio[TimingData][1].dtime)
	it = @entities_in(rotation && spatial)
	@inbounds for e in it 
    	e_rotation = rotation[e]
    	e_spatial  = spatial[e]
		n          = erotation.axis
		r          = - e_rotation.center + e_spatial.position
		theta      = e_rotation.omega * dt
		nnd        = n * dot(n, r)
		spatial[e] = Spatial(Point3f0(e_rotation.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)), e_spatial.velocity)
	end
end
struct Mover <: System end

Overseer.requested_components(::Mover) = (Spatial, TimingData)

function Overseer.update(::Mover, m::AbstractLedger)
    dt = m[TimingData][1].dtime
    spat = m[Spatial]
    for e in @entities_in(spat)
        e_spat = spat[e]
        spat[e] = Spatial(e_spat.position + e_spat.velocity*dt, e_spat.velocity)
    end
    push!(m[UpdatedComponents][1].components, Spatial)
end



