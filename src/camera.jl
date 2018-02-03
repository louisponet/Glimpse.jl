import GLFW: GetMouseButton, SetCursorPosCallback, SetKeyCallback
import GLFW: MOUSE_BUTTON_1, KEY_W, KEY_A, KEY_S, KEY_D
import GeometryTypes: Vec, Mat

const WASD_KEYS = [KEY_W, KEY_A, KEY_S, KEY_D]

@enum CamKind pixel orthographic perspective

function projmat(x::CamKind, area::Area, near::T, far::T, fov::T=zero(T)) where T
    if x == pixel
        return eye(T,4)
    elseif x == orthographic
        return projmatortho(area, near, far)
    else
        return projmatpersp(area, fov, near, far)
    end
end

#I think it would be nice to have an array flags::Vector{Symbol}, that way settings can be set
mutable struct Camera{Kind, Dim, T}
    eyepos ::Vec4{T}
    up     ::Vec4{T}
    right   ::Vec4{T}
    lookat ::Vec4{T}
    fov    ::T
    near   ::T
    far    ::T
    view   ::Mat4{T}
    projection        ::Mat4{T}
    projectionview    ::Mat4{T}
    rotation_speed    ::T
    translation_speed ::T
    mouse_pos         ::Vec{2, T}
    function (::Type{Camera{Kind, Dim}})(eyepos, up, right, lookat, fov, near, far, viewm, projm, projview, rotation_speed, translation_speed) where {Kind, Dim, T}
        new{Kind, Dim, T}(eyepos, up, right, lookat, fov, near, far, viewm, projm, projview, rotation_speed, translation_speed, Vec2f0(0))
    end
end

function (::Type{Camera{perspective}})(eyepos, lookat, up, right, area;
                fov  = 6.0f0,
                near = 0.1f0,
                far  = 100.0f0,
                rotation_speed    = 1.0f0,
                translation_speed = 1.0f0)
    projm = projmat(perspective, area, near, far, fov)
    viewm = lookatmat(eyepos, lookat, up)
    return Camera{perspective}(eyepos, up, right, lookat, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed)
end

(::Type{Camera{perspective}})() = Camera{perspective}(Vec3(0f0, 0f0, 0f0), Vec3(0f0, 1f0, 0f0), Vec3(0f0, 0f0, 1f0), Vec3(1f0,0f0,0f0), Area(0,0,standard_screen_resolution()...))


(::Type{Camera{pixel}})(center::Vec{2, Float32}, up, right, area) =
    Camera{pixel}(center, up, right, center, 0f0, 0f0, 0f0, Eye4f0(), Eye4f0(), Eye4f0(), 0f0, 0f0)
(::Type{Camera{pixel}})() where pixel = Camera{pixel}(Vec2f0(0), Vec2f0(0,1), Vec2f0(1,0), area)

function register_camera_callbacks(camera::Camera, context = current_context())
    SetCursorPosCallback(context.native_window, (window, x::Cdouble, y::Cdouble) -> begin
        mouse_move_event(camera, x, y, window)
    end)

    SetKeyCallback(context.native_window, (_1, button, _2, _3, _4) -> begin
        buttonpress_event(camera, button)
		end)
end

function mouse_move_event(camera::Camera{perspective, Dim, T} where {perspective, Dim}, x, y, window=current_context().native_window) where T
    x_ = T(x)
    y_ = T(y)
    if !GetMouseButton(window, MOUSE_BUTTON_1)
        camera.mouse_pos = Vec(x_, y_)
        return
    end
    dx = x_ - camera.mouse_pos[1]
    dy = y_ - camera.mouse_pos[2]
    println(dx, dy)
    camera.mouse_pos = Vec(x_, y_)
end
function buttonpress_event(camera::Camera, button)
    if button in WASD_KEYS
        wasd_event(camera, button)
    end
end

#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(camera::Camera{perspective, Dim, T} where {perspective, Dim}, button) where T
    if button == KEY_A
        newpos = Vec3{T}((transmat(camera.translation_speed * -camera.right) * Vec4{T}(camera.eyepos...,1.0))[1:3])
        camera.eyepos = newpos

    elseif button == KEY_D
        newpos = Vec3{T}((transmat(camera.translation_speed * camera.right) * Vec4{T}(camera.eyepos...,1.0))[1:3])
        camera.eyepos = newpos

    elseif button == KEY_W
        newpos = Vec3{T}((transmat(camera.translation_speed * camera.lookat) * Vec4{T}(camera.eyepos...,1.0))[1:3])
        camera.eyepos = newpos

    elseif button == KEY_S
        newpos = Vec3{T}((transmat(camera.translation_speed * -camera.lookat) * Vec4{T}(camera.eyepos...,1.0))[1:3])
        camera.eyepos = newpos
    end

    update_viewmat(camera)
end

function update_viewmat(cam::Camera{perspective})
    cam.view = lookatmat(cam.eyepos, cam.lookat, cam.up)
    cam.projectionview = cam.projection * cam.view
end

function rotate_cam(theta::Vec{3}, camera::Camera{perspective, Dim, T}) where T
    cam_up = camera.up
    cam_right = camera.right
    cam_dir = camera.lookat
    rotation = one(Q.Quaternion{T})
    # first the rotation around up axis, since the other rotation should be relative to that rotation
    if theta[1] != 0
        rotation *= Q.qrotation(cam_up, T(theta[1]))
    end
    # then right rotation
    if theta[2] != 0
        rotation *= Q.qrotation(cam_right, T(theta[2]))
    end
    # last rotation around camera axis
    if theta[3] != 0
        rotation *= Q.qrotation(cam_dir, T(theta[3]))
    end
    rotation
end
