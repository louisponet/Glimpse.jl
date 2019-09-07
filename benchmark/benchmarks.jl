using BenchmarkTools
using Glimpse
using Glimpse.Parameters
using Glimpse: Vec3, ComponentData, SystemData, System, Diorama, Entity, AbstractComponent, Singleton
const Gl = Glimpse

SUITE = BenchmarkGroup()

@with_kw struct Spring <: ComponentData
	center::Point3{Float64} = zero(Point3{Float64})
	k     ::Float64  = 0.01
	damping::Float64 = 0.000
end

struct Spatial <: ComponentData
	p::Vec3{Float64}
	v::Vec3{Float64}
end

struct Oscillator{S<:SystemData} <: System
	data::S
end

Oscillator(m::Diorama) = Oscillator(SystemData(m, (Spatial, Spring), ()))

function Gl.update_indices!(sys::Oscillator)
	sys.data.indices = [Gl.valid_entities(sys, Spatial, Spring)]
end

function dio_setup()
	dio = Diorama(:test, Entity[], AbstractComponent[], Singleton[], System[], interactive=false)
	Gl.add_component!(dio, Spring)
	Gl.add_component!(dio, Spatial)
	Gl.add_system!(dio, Oscillator(dio))
	return dio
end

SUITE["ECS"] = BenchmarkGroup()
SUITE["ECS"]["setup"] = @benchmarkable dio_setup()

function create_fill_entities(dio)
	for i = 1:100
		if i%2 == 0
			e = Gl.add_entity!(dio, separate = [Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0)),
										Spring()])
        else
			e = Gl.add_entity!(dio, separate = [Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0))])
		end
	end
end
function fill_entities(dio)
	for i = 1:100
		if i%2 == 0
			Gl.set_entity_component!(dio, i, Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0)), Spring())
        else
			Gl.set_entity_component!(dio, i, Spatial(Point3(30.0,1.0,1.0), Vec3(1.0,1.0,1.0)))
		end
	end
end
	
SUITE["ECS"]["create and fill entities"] =
	@benchmarkable create_fill_entities(dio) setup=(dio=dio_setup())

SUITE["ECS"]["fill entities"] =
	@benchmarkable fill_entities(dio) setup=(dio=dio_setup(); create_fill_entities(dio)) 

SUITE["ECS"]["update system indices"] =
	@benchmarkable Gl.update_system_indices!(dio) setup=(dio=dio_setup(); create_fill_entities(dio))

function Gl.update(sys::Oscillator)
	spat, spring = Gl.component(sys, Spatial), Gl.component(sys, Spring)
	for e in Gl.indices(sys)[1]
		e_spat = spat[e]
		spr  = spring[e]
		v_prev   = e_spat.v
		new_v    = v_prev - (e_spat.p - spr.center) * spr.k - v_prev * spr.damping
		new_p    = e_spat.p + v_prev * 1.0
		Gl.overwrite!(spat, Spatial(new_p, new_v), e) 
	end
end

SUITE["ECS"]["update oscillator"] =
	@benchmarkable Gl.update(dio.systems[1]) setup=(dio=dio_setup(); create_fill_entities(dio); Gl.update_system_indices!(dio))
