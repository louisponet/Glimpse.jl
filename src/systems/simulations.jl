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

	it = zip(enumerate(spat), spring)
	@inbounds for ((i, e_spat), spr) in it
      v_prev   = e_spat.velocity 
      new_v    = v_prev - (e_spat.position - spr.center) * spr.k - v_prev * spr.damping 
      new_p    = e_spat.position + v_prev * dt
      spat[i] = Spatial(new_p, new_v)
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
# struct Mover <: System
# 	data::SystemData
# end
# Mover(dio::Diorama) = Mover(SystemData(dio, (Spatial,), (TimingData,)))

# function update(sys::Mover)
# 	spatial   = component(sys, Spatial)
# 	dt        = 0.1f0*Float32(singleton(sys, TimingData).dtime)
# 	for i in valid_entities(spatial)
# 		spatial[i] = Spatial(spatial[i].position + dt*spatial[i].velocity, Vec3f0(spatial[i].position...))
# 	end
# end



