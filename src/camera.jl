import GLFW: GetMouseButton, SetCursorPosCallback, SetKeyCallback, SetWindowSizeCallback, SetFramebufferSizeCallback,
             SetScrollCallback
import GLFW: MOUSE_BUTTON_1, MOUSE_BUTTON_2, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, PRESS
import GeometryTypes: Vec, Mat

const WASD_KEYS = Int.([KEY_W, KEY_A, KEY_S, KEY_D])

@enum CamKind pixel orthographic perspective

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


function (::Type{Camera{Kind}})(eyepos::T, lookat::T, up::T, right::T; overrides...) where {Kind, T}

    defaults = mergepop_defaults!(Kind; overrides...)
    return Camera{Kind}(eyepos, lookat, up, right, defaults[:area], defaults[:fov], defaults[:near], defaults[:far], defaults[:rotation_speed], defaults[:translation_speed])
end

function (::Type{Camera{Kind}})(; overrides...) where Kind
    defaults = mergepop_defaults!(Kind, overrides...)
    Camera{Kind}(defaults[:eyepos], defaults[:lookat], defaults[:up], defaults[:right]; defaults...)
end

(::Type{Camera{pixel}})(eyepos::Vec{2, Float32}, up, right, area) =
    Camera{pixel}(eyepos, up, right, center, 0f0, 0f0, 0f0, 0f0, 0f0)
(::Type{Camera{pixel}})() = Camera{pixel}(Vec2f0(0), Vec2f0(0, 1), Vec2f0(1,0), area)

Base.eltype(::Type{Camera{Kind, Dim, T}}) where {Kind, Dim, T} = (Kind, Dim, T)
calcforward(cam::Camera) = normalize(cam.lookat-cam.eyepos)
calcright(cam::Camera)   = normalize(cross(calcforward(cam), cam.up))
calcup(cam::Camera)      = -normalize(cross(calcforward(cam), cam.right))

function update_viewmat!(cam::Camera)
    cam.view = lookatmat(cam.eyepos, cam.lookat, cam.up)
    cam.projview = cam.proj * cam.view
end

"Updates all the camera fields starting from eyepos and center, combined with the current ones"
function update!(cam::Camera)
    cam.right = calcright(cam)
    cam.up    = calcup(cam)
    update_viewmat!(cam)
end

function register_callbacks(cam::Camera, context = current_context())
    onany((pos, button) -> mouse_move_event(cam, pos, button),
          callback(context, :cursor_position),
          callback(context, :mouse_buttons))
    on(button -> buttonpress_event(cam, button),
        callback(context, :keyboard_buttons))
    on(wh -> resize_event(cam, wh...),
        callback(context, :framebuffer_size))
    on(dxdy -> scroll_event(cam, dxdy...),
        callback(context, :scroll))
end

function mouse_move_event(cam::Camera{perspective, Dim, T} where {perspective, Dim}, xy, button) where T
    x, y = xy
    x_ = T(x)
    y_ = T(y)
    dx = x_ - cam.mouse_pos[1]
    dy = y_ - cam.mouse_pos[2]
    if button[2] == Int(PRESS)
        if button[1] == Int(MOUSE_BUTTON_1)
            rotate_world(cam, dx, dy)
        elseif button[1] == Int(MOUSE_BUTTON_2)
            pan_world(cam, dx, dy)
        end
    end
    cam.mouse_pos = Vec(x_, y_)
end

function rotate_world(cam::Camera, dx, dy)
    trans1 = translmat(-cam.lookat)
    rot1   = rotate(dy * cam.rotation_speed, -cam.right)
    rot2   = rotate(-dx * cam.rotation_speed, cam.up)
    trans2 = translmat(cam.lookat)
    mat_ = trans2 * rot2 * rot1 * trans1
    cam.eyepos = Vec3f0((mat_ * Vec4(cam.eyepos..., 1.0f0))[1:3])
    cam.right = calcright(cam)
    cam.up = calcup(cam)
    update_viewmat!(cam)
end

function pan_world(cam::Camera, dx, dy)
    rt = cam.right * dx * cam.translation_speed
    ut = -cam.up   * dy * cam.translation_speed
    cam.lookat += rt + ut
    cam.eyepos += rt + ut
    update_viewmat!(cam)
end

function buttonpress_event(cam::Camera, button)
    if button[3] == Int(PRESS)
        if button[1] in WASD_KEYS
            wasd_event(cam, button)
        elseif button[1] == Int(KEY_Q)
            cam.fov -= 1
            cam.proj = projmatpersp( Area(0,0,standard_screen_resolution()...), cam.fov,0.1f0, 300f0)
        end
    end
end

#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(cam::Camera{perspective, Dim, T} where {perspective, Dim}, button) where T
    #ok this is a bit hacky but fine
    origlen = norm(cam.eyepos)
    if button[1] == Int(KEY_A)
        #the world needs to move in the opposite direction
        newpos = Vec3{T}((translmat(cam.translation_speed * cam.right) * Vec4{T}(cam.eyepos...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button[1] == Int(KEY_D)
        newpos = Vec3{T}((translmat(cam.translation_speed * -cam.right) * Vec4{T}(cam.eyepos...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button[1] == Int(KEY_W)
        newpos = Vec3{T}((translmat(cam.translation_speed * calcforward(cam)) * Vec4{T}(cam.eyepos...,1.0))[1:3])

    elseif button[1] == Int(KEY_S)
        newpos = Vec3{T}((translmat(cam.translation_speed * -calcforward(cam)) * Vec4{T}(cam.eyepos...,1.0))[1:3])

    end
    cam.eyepos = newpos
    cam.right = calcright(cam)
    update_viewmat!(cam)
end

function resize_event(cam::Camera, w, h)
    cam.proj = projmat(eltype(cam)[1], w, h, cam.near, cam.far, cam.fov)
    cam.projview = cam.proj * cam.view
end

function scroll_event(cam::Camera, dx, dy)
    translation = calcforward(cam) * dy * cam.translation_speed * norm(cam.eyepos - cam.lookat)
    cam.eyepos += translation
    update_viewmat!(cam)
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
