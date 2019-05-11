# These are all the systems used for the general running of Dioramas
const SHIT_KEYS = Int.([GLFW.KEY_LEFT_SHIFT, GLFW.KEY_RIGHT_SHIFT])

struct Sleeper <: System
	data ::SystemData

	Sleeper(dio::Diorama) = new(SystemData(dio, (), (TimingData, Canvas)))
end 

function update(sleeper::Sleeper)
	swapbuffers(singleton(sleeper, Canvas))
	sd         = singletons(sleeper)[1]
	curtime    = time()
	sleep_time = sd.preferred_fps - (curtime - sd.time)
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

struct Resizer <: System
	data ::SystemData

	Resizer(dio::Diorama) = new(SystemData(dio, (), (Canvas, RenderTarget)))
end

function update(sys::Resizer)
	c   = singleton(sys, Canvas)
	fwh = callback_value(c, :framebuffer_size)
	resize!(c, fwh)
	for rt in singletons(sys, RenderTarget)
		resize!(rt, fwh)
	end
end

# Mouse Picking Stuff
Base.@kwdef struct Selectable <: ComponentData
	selected::Bool = false
end

struct AABB <: ComponentData
	origin  ::Vec3f0
	diagonal::Vec3f0
end

struct AABBGenerator <: System
	data ::SystemData

	AABBGenerator(dio::Diorama) =
		new(SystemData(dio, (Geometry, AABB, Selectable), ()))
end

function update_indices!(sys::AABBGenerator)
	sys.data.indices = [setdiff(valid_entities(sys, PolygonGeometry, Selectable), valid_entities(sys, AABB))]
end

function update(sys::AABBGenerator)
	poly = component(sys, PolygonGeometry)
	aabb = component(sys, AABB)
	for e in indices(sys)[1]
		t_rect = GeometryTypes.AABB(poly[e].geometry)
		aabb[e] = AABB(t_rect.origin, t_rect.widths)
	end
end

struct MousePicker <: System
	data ::SystemData

	MousePicker(dio::Diorama) =
		new(SystemData(dio, (Selectable, AABB, Camera3D, Spatial), (Canvas,)))
end

function update_indices!(sys::MousePicker)
	sys.data.indices = [valid_entities(sys, Camera3D, Spatial), valid_entities(sys, AABB, Selectable, Spatial)]
end

function aabb_ray_intersect(aabb::AABB, entity_pos::Point3f0, ray_origin::Point3f0, ray_direction::Vec3f0)
	dirfrac = 1.0f0 ./ ray_direction
	right   = aabb.origin + aabb.diagonal

	real_origin = aabb.origin + entity_pos
	real_right  = right + entity_pos
	t1 = (real_origin - ray_origin) .* dirfrac
	t2 = (real_right - ray_origin)  .* dirfrac
	tsmaller = min.(t1, t2)
	tbigger  = max.(t1,t2)

	tmin = maximum(tsmaller)
	tmax = minimum(tbigger)
	

	return tmin < tmax
end

function update(sys::MousePicker)
	c   = singleton(sys, Canvas)
	mouse_buttons   = callback_value(c, :mouse_buttons)
	cursor_position = callback_value(c, :cursor_position)
	keyboard_button = callback_value(c, :keyboard_buttons)
	wh = size(c)
	camid = indices(sys)[1][1]
	cam = component(sys, Camera3D)[camid]
	eye = component(sys, Spatial)[camid].position

	cam_proj = cam.proj
	cam_view = cam.view

	spat = component(sys, Spatial)
	aabb = component(sys, AABB)
	sel  = component(sys, Selectable)

	if keyboard_button[3] == Int(GLFW.PRESS) && keyboard_button[1] ∈ SHIT_KEYS &&
		mouse_buttons[2] == Int(GLFW.PRESS) && mouse_buttons[1] == Int(GLFW.MOUSE_BUTTON_1)

		screenspace = (2 * cursor_position[1] / wh[1] - 1,  1-2*cursor_position[2]/wh[2])
		ray_clip    = Vec4f0(screenspace..., -1.0, 1.0)
		ray_eye     = Vec4f0((inv(cam_proj) * ray_clip)[1:2]..., -1.0, 0.0)
		ray_dir     = normalize(Vec3f0((inv(cam_view) * ray_eye)[1:3]...))

		for e in indices(sys)[2]
			e_aabb = aabb[e]
			e_spat = spat[e]
			if aabb_ray_intersect(e_aabb, e_spat.position, eye, ray_dir)
				sel[e] = Selectable(true)
			end
		end
	end
end


















