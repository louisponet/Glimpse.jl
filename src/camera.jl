import GLFW: GetMouseButton, SetCursorPosCallback, SetKeyCallback, SetWindowSizeCallback, SetFramebufferSizeCallback,
             SetScrollCallback
import GLFW: MOUSE_BUTTON_1, MOUSE_BUTTON_2, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, PRESS
import GeometryTypes: Vec, Mat

const WASD_KEYS = Int.([KEY_W, KEY_A, KEY_S, KEY_D])


function projmat(x::CamKind, w::Int, h::Int, near::T, far::T, fov::T) where T
    if x == pixel
        return eye(T,4)
    elseif x == orthographic
        return projmatortho(w, h, near, far)
    else
        return projmatpersp(w, h, fov, near, far)
    end
end

projmat(x::CamKind, wh::SimpleRectangle, args...) =
    projmat(x, wh.w, wh.h, args...)

#I think it would be nice to have an array flags::Vector{Symbol}, that way settings can be set

function Camera3D(eyepos, lookat, up, right, area, fov, near, far, rotation_speed, translation_speed)
    up    = normalizeperp(lookat - eyepos, up)
    right = normalize(cross(lookat - eyepos, up))

    viewm = lookatmat(eyepos, lookat, up)
    projm = projmat(perspective, area, near, far, fov)
    return Camera3D(lookat, up, right, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed, Vec2f0(0), 0.0f0, 0.0f0)
end

function Camera3D(eyepos, lookat, up, right; overrides...)
    defaults = mergepop_defaults!(perspective; overrides...)
    return Camera3D(eyepos, lookat, up, right, defaults[:area], defaults[:fov], defaults[:near], defaults[:far], defaults[:rotation_speed], defaults[:translation_speed])
end

function Camera3D(eyepos; overrides...)
    defaults = mergepop_defaults!(perspective, overrides...)
    return Camera3D(eyepos, defaults[:lookat], defaults[:up], defaults[:right]; defaults...)
end

function Camera3D(; overrides...)
    defaults = mergepop_defaults!(perspective, overrides...)
    return Camera3D(defaults[:eyepos], defaults[:lookat], defaults[:up], defaults[:right]; defaults...)
end


abstract type InteractiveSystem <: SystemKind end
struct Camera <: InteractiveSystem end

camera_system(dio::Diorama) = System{Camera}(dio, (Spatial, Camera3D,), ())

function update(updater::System{Camera})
	camera  = component(updater, Camera3D)
	spatial = component(updater, Spatial)
	if isempty(component(updater,Camera3D))
		return
	end

	context = current_context()
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
	    cam.mouse_pos = Vec(x, y)
	    if mouse_button[2] == Int(PRESS)

	        if mouse_button[1] == Int(MOUSE_BUTTON_1) #rotation
			    trans1  = translmat(-cam.lookat)
			    rot1    = rotate(dy * cam.rotation_speed, -cam.right)
			    rot2    = rotate(-dx * cam.rotation_speed, cam.up)
			    trans2  = translmat(cam.lookat)
			    mat_    = trans2 * rot2 * rot1 * trans1
			    new_pos = Point3f0((mat_ * Vec4(new_pos..., 1.0f0))[1:3])

	        elseif mouse_button[1] == Int(MOUSE_BUTTON_2) #panning
				rt          = cam.right * dx * cam.translation_speed
				ut          = -cam.up   * dy * cam.translation_speed
				cam.lookat += rt + ut
				new_pos    += rt + ut
	        end
        end

		#keyboard stuff
	    if keyboard_button[3] == Int(PRESS)
	        if keyboard_button[1] in WASD_KEYS
	            new_pos = wasd_event(new_pos, cam, keyboard_button)
	        elseif keyboard_button[1] == Int(KEY_Q)
	            cam.fov -= 1
	            cam.proj = projmatpersp( Area(0,0,standard_screen_resolution()...), cam.fov,0.1f0, 300f0)
	        end
	    end

	    #resize stuff
	    cam.proj      = projmat(perspective, w, h, cam.near, cam.far, cam.fov) #TODO only perspective

	    #scroll stuff no dx
	    translation   = calcforward(new_pos, cam) * (scroll_dy - cam.scroll_dy)* cam.translation_speed * norm(new_pos - cam.lookat)
	    cam.scroll_dy = scroll_dy
	    new_pos      += translation

		# update_viewmat
	    cam.right     = calcright(new_pos, cam)
	    cam.up        = calcup(new_pos, cam)
	    cam.view      = lookatmat(new_pos, cam.lookat, cam.up)
	    cam.projview  = cam.proj * cam.view
		spatial[i]    = Spatial(new_pos, spat.velocity)
    end
end

calcforward(position, cam::Camera3D) = normalize(cam.lookat-position)
calcright(position, cam::Camera3D)   = normalize(cross(calcforward(position, cam), cam.up))
calcup(position, cam::Camera3D)      = -normalize(cross(calcforward(position, cam), cam.right))


#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(position, cam::Camera3D, button)
    #ok this is a bit hacky but fine
    origlen = norm(position)
    if button[1] == Int(KEY_A)
        #the world needs to move in the opposite direction
        newpos = Vec3f0((translmat(cam.translation_speed * cam.right) * Vec4f0(position...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button[1] == Int(KEY_D)
        newpos = Vec3f0((translmat(cam.translation_speed * -cam.right) * Vec4f0(position...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button[1] == Int(KEY_W)
        newpos = Vec3f0((translmat(cam.translation_speed * calcforward(position, cam)) * Vec4f0(position...,1.0))[1:3])

    elseif button[1] == Int(KEY_S)
        newpos = Vec3f0((translmat(cam.translation_speed * -calcforward(position, cam)) * Vec4f0(position...,1.0))[1:3])

    end
    return newpos
end

#----------------------------------DEFAULTS----------------------------#
perspective_defaults() = Dict{Symbol, Any}(:eyepos => Vec3(0f0, -1f0, 0f0),
                                               :lookat => Vec3(0f0,  0f0, 0f0),
                                               :up     => Vec3(0f0,  0f0, 1f0),
                                               :right  => Vec3(1f0,  0f0, 0f0),
                                               :area   => Area(0,0,  standard_screen_resolution()...),
                                               :fov    => 42f0,
                                               :near   => 0.1f0,
                                               :far    => 300f0,
                                               :rotation_speed    => 0.001f0,
                                               :translation_speed => 0.01f0)
orthographic_defaults() = perspective_defaults()
pixel_defaults()        = merge(perspective_defaults(), Dict(
								:fov  => 0f0,
								:near => 0f0,
								:far  => 0f0,
								:rotation_speed    => 0f0,
								:translation_speed => 0f0)
								)

function merge_defaults(x::CamKind; overrides...)
    if x == orthographic
        merge(orthographic_defaults(), overrides)
    elseif x == perspective
        merge(perspective_defaults(), overrides)
    end
end

function mergepop_defaults!(x::CamKind; overrides...)
    if x == orthographic
        mergepop!(orthographic_defaults(), overrides)
    elseif x == perspective
        mergepop!(perspective_defaults(), overrides)
    end
end
