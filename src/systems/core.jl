# These are all the systems used for the general running of Dioramas
struct Timer <: System end

Overseer.requested_components(::Timer) = (TimingData,)

function Overseer.update(::Timer, m::AbstractLedger)
	for t in m[TimingData]
		nt = time()
		t.dtime = t.reversed ? - nt + t.time : nt - t.time
		t.time    = nt
		t.frames += 1
	end
end

struct Sleeper <: System end
Overseer.requested_components(::Sleeper) = (TimingData, Canvas)

function Overseer.update(::Sleeper, m::AbstractLedger)
	sd = m[TimingData]
	@timeit sd[1].timer "swapping" swapbuffers(m[Canvas][1])
	curtime    = time()
	dt = (curtime - sd[1].time)
	sleep_time = 1/sd[1].preferred_fps - dt
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
	curtime    = time()
	dt = (curtime - sd[1].time)
end

struct Resizer <: System end
Overseer.requested_components(::Resizer) = (Canvas, IOTarget)

function Overseer.update(::Resizer, m::AbstractLedger)
	c = m[Canvas][1]
	fwh = c.framebuffer_size
	resize!(c, fwh)
	for c in components(m)
		if eltype(c) <: RenderTarget
			for rt in c
				resize!(rt, fwh)
			end
		end
	end

end

# Mouse Picking Stuff
@component_with_kw struct Selectable <: ComponentData
	selected::Bool = false
	color_modifier ::Float32 = 1.3f0
end

@component struct AABB
	origin  ::Vec3f0
	diagonal::Vec3f0
end

struct AABBGenerator <: System end

Overseer.requested_components(::AABBGenerator) = (PolygonGeometry, AABB, Selectable, IDColor)

function Overseer.update(::AABBGenerator, m::AbstractLedger)
	# geometry, aabb, selectable = m[PolygonGeometry], m[AABB], m[Selectable]
	idc, selectable =  m[IDColor], m[Selectable]
	i = length(idc)
    for e in @entities_in(selectable && !idc)
        idc[e] = IDColor(RGBf0(((i & 0x000000FF) >>  0)/ 255,((i & 0x0000FF00) >>  8)/255, ((i & 0x00FF0000) >> 16)/255))
        i+=1
    end
end

struct MousePicker <: System end

Overseer.requested_components(::MousePicker) = (Selectable, AABB, Camera3D, Spatial, UniformColor, Canvas, UpdatedComponents)

function Overseer.update(::MousePicker, m::AbstractLedger)
	sel                = m[Selectable]
	aabb               = m[AABB]
	camera             = m[Camera3D]
	spat               = m[Spatial]
	col                = m[UniformColor]
	canvas             = m[Canvas]
	updated_components = m[UpdatedComponents][1]
	c                  = canvas[1]
	mouse_buttons      = c.mouse_buttons
	cursor_position    = c.cursor_position
	keyboard_button    = c.keyboard_buttons
	wh                 = size(c)
	cam                = camera[1]
	camid              = Entity(camera, 1)
	eye                = spat[camid].position

	cam_proj           = cam.proj
	cam_view           = cam.view


	@inbounds if keyboard_button[3] == Int(GLFW.PRESS) && keyboard_button[1] ∈ CTRL_KEYS &&
		mouse_buttons[2] == Int(GLFW.PRESS) && mouse_buttons[1] == Int(GLFW.MOUSE_BUTTON_1)
		screenspace = (2 * cursor_position[1] / wh[1] - 1,  1-2*cursor_position[2]/wh[2])
		ray_clip    = Vec4f0(screenspace..., -1.0, 1.0)
		ray_eye     = Vec4f0((inv(cam_proj) * ray_clip)[1:2]..., -1.0, 0.0)
		ray_dir     = normalize(Vec3f0((inv(cam_view) * ray_eye)[1:3]...))
		for e in @entities_in(sel && aabb && spat && col)
    		s       = sel[e]
    		e_color = col[e]
    		e_spat  = spat[e]
			o_c    = e_color.color
			mod    = s.color_modifier
			if aabb_ray_intersect(aabb[e], e_spat.position, eye, ray_dir)
				was_selected = s.selected
				sel[e] = Selectable(true, s.color_modifier)
				if !was_selected
					col[e] = UniformColor(RGBA(o_c.r * mod, o_c.g * mod, o_c.b * mod, o_c.alpha))
					push!(updated_components.components, UniformColor)
				end
			else
				was_not_selected = s.selected
				sel[e] = Selectable(false, s.color_modifier)
				if was_not_selected
					col[e] = UniformColor(RGBA(o_c.r / mod, o_c.g / mod, o_c.b / mod, o_c.alpha))
					push!(updated_components.components, UniformColor)
				end
			end
		end
	end
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

