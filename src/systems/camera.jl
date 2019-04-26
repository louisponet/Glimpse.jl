import GLFW: MOUSE_BUTTON_1, MOUSE_BUTTON_2, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, PRESS
# import GeometryTypes: Vec, Mat

const WASD_KEYS = Int.([KEY_W, KEY_A, KEY_S, KEY_D])

#I think it would be nice to have an array flags::Vector{Symbol}, that way settings can be set
abstract type InteractiveSystem <: SystemKind end
struct Camera <: InteractiveSystem end

camera_system(dio::Diorama) = System{Camera}(dio, (Spatial, Camera3D,), (Canvas,))

function update(updater::System{Camera})
	camera  = component(updater, Camera3D)
	spatial = component(updater, Spatial)
	if isempty(component(updater,Camera3D))
		return
	end

	context = singleton(updater, Canvas)
	pollevents(context)

	x, y                 = Float32.(callback_value(context, :cursor_position))
	mouse_button         = callback_value(context, :mouse_buttons)
	keyboard_button      = callback_value(context, :keyboard_buttons)
    w, h                 = callback_value(context, :framebuffer_size)
    scroll_dx, scroll_dy = callback_value(context, :scroll)

	for i in valid_entities(camera, spatial)
		cam     = camera[i]
		spat    = spatial[i]
		new_pos = Point3f0(spat.position)
		#world orientation/mouse stuff
	    dx      = x - cam.mouse_pos[1]
	    dy      = y - cam.mouse_pos[2]
	    new_mouse_pos = Vec(x, y)
	    new_lookat    = cam.lookat
	    if mouse_button[2] == Int(PRESS)

	        if mouse_button[1] == Int(MOUSE_BUTTON_1) #rotation
			    trans1  = translmat(-cam.lookat)
			    rot1    = rotate(dy * cam.rotation_speed, -cam.right)
			    rot2    = rotate(-dx * cam.rotation_speed, cam.up)
			    trans2  = translmat(cam.lookat)
			    mat_    = trans2 * rot2 * rot1 * trans1
			    new_pos = Point3f0((mat_ * Vec4(new_pos..., 1.0f0))[1:3])

	        elseif mouse_button[1] == Int(MOUSE_BUTTON_2) #panning
				rt          = cam.right * dx *0.5* cam.translation_speed
				ut          = -cam.up   * dy *0.5* cam.translation_speed
				new_lookat += rt + ut
				new_pos    += rt + ut
	        end
        end

		#keyboard stuff
	    if keyboard_button[3] == Int(PRESS) || keyboard_button[3] == Int(GLFW.REPEAT)
	        if keyboard_button[1] in WASD_KEYS
	            new_pos, new_lookat = wasd_event(new_pos, cam, keyboard_button)
	        # elseif keyboard_button[1] == Int(KEY_Q)
	            # cam.fov -= 1
	            # cam.proj = projmatpersp( Area(0,0,standard_screen_resolution()...), cam.fov,0.1f0, 300f0)
	        end
	    end

	    #resize stuff
	    new_proj = projmat(perspective, w, h, cam.near, cam.far, cam.fov) #TODO only perspective

	    #scroll stuff no dx
	    new_forward   = forward(new_pos, new_lookat)
	    new_scroll_dy = scroll_dy
	    new_pos      += Point3f0(new_forward * (scroll_dy - cam.scroll_dy) * cam.translation_speed/2)

		# update_viewmat
		u_forward    = normalize(new_forward)
	    new_right    = unitright(u_forward, cam.up)
	    new_up       = unitup(u_forward, new_right)
	    new_view     = lookatmat(new_pos, new_lookat, new_up)
	    new_projview = new_proj * new_view
		spatial[i]   = @set spat.position = new_pos
		overwrite!(camera, Camera3D(new_lookat, new_up, new_right, cam.fov, cam.near, cam.far, new_view,
		                            new_proj, new_projview, cam.rotation_speed, cam.translation_speed,
		                            new_mouse_pos, cam.scroll_dx, new_scroll_dy), i)
    end
end

unitforward(position, lookat) = normalize(forward(position, lookat))
unitright(forward, up)        = normalize(right(forward, up))
unitup(forward, right)        = normalize(up(forward, right))

forward(position, lookat) = lookat - position
right(forward, up)        = cross(forward, up)
up(forward, right)        = cross(right, forward)


#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(position, cam::Camera3D, button)
    #ok this is a bit hacky but fine
    # origlen = norm(position)
    new_lookat = cam.lookat
    if button[1] == Int(KEY_A)
	    move        = cam.translation_speed * 5 * cam.right
        #the world needs to move in the opposite direction
        position   -= move
        new_lookat -= move
	end
    if button[1] == Int(KEY_D)
	    move        = cam.translation_speed * 5 * cam.right
        position   += move
        new_lookat += move
	end
    if button[1] == Int(KEY_W)
	    move = unitforward(position, cam.lookat) * 5 * cam.translation_speed
        position   += move
        new_lookat += move

	end
    if button[1] == Int(KEY_S)

	    move = unitforward(position, cam.lookat) * 5 * cam.translation_speed
        position   -= move
        new_lookat -= move

    end
    return position, new_lookat
end
