abstract type SimulationSystem <: System end

Base.@kwdef struct Spring <: ComponentData
	center::Point3f0 = zero(Point3f0)
	k     ::Float32  = 0.01f0
	damping::Float32 = 0.0001f0
end

struct Oscillator <: System end


requested_components(::Oscillator) = (Spatial, Spring, UpdatedComponents, TimingData)

function update(::Oscillator, m::Manager)
	spat, spring=m[Spatial], m[Spring]
	td     = m[TimingData][1] 
	dt     = td.dtime

	it = ECS.pointer_zip(spat, spring)
	@inbounds for (spat_ptr, spr_ptr) in it
		e_spat = unsafe_load(spat_ptr)
		spr = unsafe_load(spr_ptr)
		v_prev   = e_spat.velocity 
		new_v    = v_prev - (e_spat.position - spr.center) * spr.k - v_prev * spr.damping
		unsafe_store!(spat_ptr, Spatial(e_spat.potiion, new_v))
	end
	push!(m[UpdatedComponents][1].components, Spatial)
end

struct Rotation <: ComponentData
	omega::Float32
	center::Point3f0
	axis::Vec3f0
end

struct Rotator <: System  end
ECS.requested_components(::Rotator) = (Spatial, Rotation, TimingData)

function ECS.update(::Rotator, dio::ECS.AbstractManager)
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
struct Mover <: System end

ECS.requested_components(::Mover) = (Spatial, TimingData)

function update(::Mover, m::ECS.AbstractManager)
    dt = m[TimingData][1].dtime
    spat = m[Spatial]
    for (i, e_spat) in enumerate(spat)
        spat[i] = Spatial(e_spat.position + e_spat.velocity*dt, e_spat.velocity)
    end
    push!(m[UpdatedComponents][1].components, Spatial)
end



