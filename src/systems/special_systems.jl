
Base.@kwdef struct Spring <: ComponentData
	center::Point3f0 = zero(Point3f0)
	k     ::Float32  = 0.01f0
	damping::Float32 = 0.0001f0
end

struct Oscillator <: SystemKind end

oscillator_system(dio) = System{Oscillator}(dio, (Spatial, Spring), (TimingData, UpdatedComponents))

function update_indices!(sys::System{Oscillator})
	sp_es  = valid_entities(component(sys, Spatial))
	spring = shared_component(sys, Spring)
	tids   = Vector{Int}[]
	for spr in spring.shared
		push!(tids,  shared_entities(spring, spr) ∩ sp_es)
	end
	sys.indices = tids
end

function update(sys::System{Oscillator})
	spat   = component(sys, Spatial)
	spring = shared_component(sys, Spring)
	td     = singleton(sys, TimingData)
	dt     = td.dtime
	for (is, spr) in enumerate(spring.shared)
		Threads.@threads for e in sys.indices[is] 
			e_spat   = spat[e]
			v_prev   = e_spat.velocity
			new_v    = v_prev - (e_spat.position - spr.center) * spr.k - v_prev * spr.damping
			new_p    = e_spat.position + v_prev * dt
			overwrite!(spat, Spatial(new_p, new_v), e)
		end
	end
	update_component!(singleton(sys, UpdatedComponents), Spatial)
end

struct Rotation <: ComponentData
	omega ::Float32
	center::Point3f0
	axis  ::Vec3f0
end
# RotationComponent(id) = Component(id, Rotation)

struct Rotator <: SystemKind end
rotator_system(dio) = System{Rotator}(dio, (Spatial, Rotation), (TimingData,))

function update(sys::System{Rotator})
	rotation  = component(sys, Rotation)
	spatial   = component(sys, Spatial)
	dt        = Float32(singleton(sys,TimingData).dtime)
	for i in valid_entities(rotation, spatial)
		e_rotation = rotation[i]
		n          = e_rotation.axis
		r          = - e_rotation.center + spatial[i].position
		theta      = e_rotation.omega * dt
		nnd        = n * dot(n, r)
		spatial[i] = Spatial(Point3f0(e_rotation.center + nnd + (r - nnd) * cos(theta) + cross(r, n) * sin(theta)),
							 spatial[i].velocity)
	end
end

struct Mover <: SystemKind end
mover_system(dio) = System{Mover}(dio, (Spatial,), (TimingData,))

function update(sys::System{Mover})
	spatial   = component(sys, Spatial)
	dt        = 0.1f0*Float32(singleton(sys, TimingData).dtime)
	for i in valid_entities(spatial)
		spatial[i] = Spatial(spatial[i].position + dt*spatial[i].velocity, Vec3f0(spatial[i].position...))
	end
end



