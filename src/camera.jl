import GLFW: GetMouseButton, SetCursorPosCallback, SetKeyCallback, SetWindowSizeCallback, SetFramebufferSizeCallback,
             SetScrollCallback
import GLFW: MOUSE_BUTTON_1, MOUSE_BUTTON_2, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q
import GeometryTypes: Vec, Mat

const WASD_KEYS = [KEY_W, KEY_A, KEY_S, KEY_D]

@enum CamKind pixel orthographic perspective

function projmat(x::CamKind, area::Area, near::T, far::T, fov::T) where T
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
    eyepos ::Vec{Dim, T}
    lookat ::Vec{Dim, T}
    up     ::Vec{Dim, T}
    right  ::Vec{Dim, T}
    fov    ::T
    near   ::T
    far    ::T
    view   ::Mat4{T}
    proj        ::Mat4{T}
    projview    ::Mat4{T}
    rotation_speed    ::T
    translation_speed ::T
    mouse_pos         ::Vec{2, T}

    function (::Type{Camera{Kind}})(eyepos::Vec{Dim, T}, lookat, up, right, area, fov, near, far, rotation_speed, translation_speed) where {Kind, Dim, T}


        up    = normalizeperp(lookat - eyepos, up)
        right = normalize(cross(lookat - eyepos, up))

        viewm = lookatmat(eyepos, lookat, up)
        projm = projmat(Kind, area, near, far, fov)

        new{Kind, Dim, T}(eyepos, lookat, up, right, fov, near, far, viewm, projm, projm * viewm, rotation_speed, translation_speed, Vec2f0(0))
    end
end

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

function register_camera_callbacks(cam::Camera, context = current_context())
    SetCursorPosCallback(context.native_window, (window, x::Cdouble, y::Cdouble) -> begin
        mouse_move_event(cam, x, y, window)
    end)

    SetKeyCallback(context.native_window, (_1, button, _2, _3, _4) -> begin
        buttonpress_event(cam, button)
		end)

    SetFramebufferSizeCallback(context.native_window, (window, w::Cint, h::Cint,) -> begin
        orig        = context.area
        w_, h_      = Int(w), Int(h)
        context.area = Area(orig.x, orig.y, w_, h_)
        glViewport(0, 0, w_, h_)
        resize_event(cam, context.area)
    end)

    SetScrollCallback(context.native_window, (window, dx::Cdouble, dy::Cdouble) -> begin
        scroll_event(cam, dx, dy)
    end)
end

function mouse_move_event(cam::Camera{perspective, Dim, T} where {perspective, Dim}, x, y, window=current_context().native_window) where T
    x_ = T(x)
    y_ = T(y)
    dx = x_ - cam.mouse_pos[1]
    dy = y_ - cam.mouse_pos[2]
    if GetMouseButton(window, MOUSE_BUTTON_1)
        rotate_world(cam, dx, dy)
    elseif GetMouseButton(window, MOUSE_BUTTON_2)
        pan_world(cam, dx, dy)
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
    ut = cam.up    * dy * cam.translation_speed
    cam.lookat += rt + ut
    cam.eyepos += rt + ut
    update_viewmat!(cam)
end

function buttonpress_event(cam::Camera, button)
    if button in WASD_KEYS
        wasd_event(cam, button)
    elseif button == KEY_Q
        cam.fov -= 1
        cam.proj = projmatpersp( Area(0,0,standard_screen_resolution()...), cam.fov,0.1f0, 100f0)
    end
end

#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(cam::Camera{perspective, Dim, T} where {perspective, Dim}, button) where T
    #ok this is a bit hacky but fine
    origlen = norm(cam.eyepos)
    if button == KEY_A
        #the world needs to move in the opposite direction
        newpos = Vec3{T}((translmat(cam.translation_speed * cam.right) * Vec4{T}(cam.eyepos...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button == KEY_D
        newpos = Vec3{T}((translmat(cam.translation_speed * -cam.right) * Vec4{T}(cam.eyepos...,1.0))[1:3])
        newpos = origlen == 0 ? newpos : normalize(newpos) * origlen

    elseif button == KEY_W
        newpos = Vec3{T}((translmat(cam.translation_speed * calcforward(cam)) * Vec4{T}(cam.eyepos...,1.0))[1:3])

    elseif button == KEY_S
        newpos = Vec3{T}((translmat(cam.translation_speed * -calcforward(cam)) * Vec4{T}(cam.eyepos...,1.0))[1:3])

    end
    cam.eyepos = newpos
    cam.right = calcright(cam)
    update_viewmat!(cam)
end

function resize_event(cam::Camera, area::Area)
    cam.proj = projmat(eltype(cam)[1], area, cam.near, cam.far, cam.fov)
    cam.projview = cam.proj * cam.view
end

function scroll_event(cam::Camera, dx, dy)
    translation = calcforward(cam) * dy * cam.translation_speed
    cam.eyepos += translation
    update_viewmat!(cam)
end

include("defaults/camera.jl")
