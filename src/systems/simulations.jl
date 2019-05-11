abstract type SimulationSystem <: System end

struct Timer <: SimulationSystem
	data ::SystemData

	Timer(dio::Diorama) = new(SystemData(dio, (), (TimingData,)))
end 

function update(timer::Timer)
	sd = system_data(timer).singletons[1]
	nt         = time()
	sd.dtime   = sd.reversed ? - nt + sd.time : nt - sd.time
	sd.time    = nt
	sd.frames += 1
end

Base.@kwdef struct Spring <: ComponentData
	center::Point3f0 = zero(Point3f0)
	k     ::Float32  = 0.01f0
	damping::Float32 = 0.0001f0
end

struct Oscillator <: System
	data ::SystemData
end
Oscillator(dio::Diorama) = Oscillator(SystemData(dio, (Spatial, Spring), (TimingData, UpdatedComponents)))

system_data(o::Oscillator) = o.data

function update_indices!(sys::Oscillator)
	sp_es  = valid_entities(component(sys, Spatial))
	spring = shared_component(sys, Spring)
	tids   = Vector{Int}[]
	for spr in spring.shared
		push!(tids,  shared_entities(spring, spr) ∩ sp_es)
	end
	sys.data.indices = tids
end

function update(sys::Oscillator)
	spat   = component(sys, Spatial)
	spring = shared_component(sys, Spring)
	td     = singleton(sys, TimingData)
	dt     = td.dtime
	for (is, spr) in enumerate(spring.shared)
		Threads.@threads for e in indices(sys)[is] 
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

struct Rotator <: System
	data ::SystemData
end
Rotator(dio::Diorama) = Rotator(SystemData(dio, (Spatial, Rotation), (TimingData,)))
system_data(r::Rotator) = r.data

function update(sys::Rotator)
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

struct Mover <: System
	data::SystemData
end
Mover(dio::Diorama) = Mover(SystemData(dio, (Spatial,), (TimingData,)))

function update(sys::Mover)
	spatial   = component(sys, Spatial)
	dt        = 0.1f0*Float32(singleton(sys, TimingData).dtime)
	for i in valid_entities(spatial)
		spatial[i] = Spatial(spatial[i].position + dt*spatial[i].velocity, Vec3f0(spatial[i].position...))
	end
end


