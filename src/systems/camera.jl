@enum CameraKind Perspective Orthographic Pixel

# import GeometryBasics: Vec, Mat
@component @with_kw mutable struct Camera3D
    lookat::Vec3f0             = zero(Vec3f0)
    up::Vec3f0                 = Z_AXIS
    right::Vec3f0              = X_AXIS
    fov::Float32               = 42.0f0
    near::Float32              = 0.1f0
    far::Float32               = 3000.0f0
    view                       :: Mat4f0
    proj                       :: Mat4f0
    projview                   :: Mat4f0
    rotation_speed::Float32    = 0.001f0
    translation_speed::Float32 = 0.02f0
    locked::Bool               = false
    camerakind::CameraKind     = Perspective
end

function Camera3D(width_pixels::Integer, height_pixels::Integer; eyepos = -10 * Y_AXIS,
                  lookat = zero(Vec3f0), up = Z_AXIS, right = X_AXIS, near = 0.1f0,
                  far = 3000.0f0, fov = 42.0f0, camerakind = Perspective)
    up    = normalizeperp(lookat - eyepos, up)
    right = normalize(cross(lookat - eyepos, up))

    viewm = lookatmat(eyepos, lookat, up)
    zoom  = norm(forward(eyepos, lookat))
    projm = projmat(width_pixels, height_pixels, zoom, near, far, fov, camerakind)
    return Camera3D(; lookat = lookat, up = up, right = right, fov = fov, near = near,
                    far = far, view = viewm, proj = projm, projview = projm * viewm,
                    camerakind = camerakind)
end
function projmat(w::Integer, h::Integer, cam::Camera3D, zoom)
    return projmat(w, h, zoom, cam.near, cam.far, cam.fov, cam.camerakind)
end

function projmat(w::Integer, h::Integer, zoom, near, far, fov, camerakind)
    aspect = w / h
    h = tan(fov / 360.0f0 * pi) * near
    w = h * aspect
    if camerakind == Pixel
        return diagm(ones(Float32, 4))
    elseif camerakind == Orthographic
        h, w = h * zoom * 23.0f0, w * zoom * 23.0f0
        return projmatortho(Float32, -w, w, -h, h, near, far)
    elseif camerakind == Perspective
        return projmatpersp(Float32, fov, aspect, near, far)
    end
end

abstract type InteractiveSystem <: System end

struct CameraOperator <: InteractiveSystem end

Overseer.requested_components(::CameraOperator) = (Spatial, Camera3D, Canvas)

function Overseer.update(::CameraOperator, m::AbstractLedger)
    canvas = singleton(m, Canvas)
    mouse = singleton(m, Mouse)
    keyboard = singleton(m, Keyboard)

    x, y         = mouse.x, mouse.y
    mouse_button = canvas.mouse_buttons
    w, h         = size(canvas)

    scroll_dx, scroll_dy = mouse.dscroll
    dx = mouse.dx
    dy = mouse.dy

    @inbounds for e in @entities_in(m, Spatial && Camera3D)
        e.locked && continue
        cam = e[Camera3D]
        new_pos = Point3f0(e.position)
        #world orientation/mouse stuff
        new_lookat = cam.lookat
        if pressed(mouse) && !(keyboard.button ∈ CTRL_KEYS && pressed(keyboard))
            if mouse.button == GLFW.MOUSE_BUTTON_1 #rotation
                trans1  = translmat(-cam.lookat)
                rot1    = rotate(dy * cam.rotation_speed, -cam.right)
                rot2    = rotate(-dx * cam.rotation_speed, cam.up)
                trans2  = translmat(cam.lookat)
                mat_    = trans2 * rot2 * rot1 * trans1
                new_pos = Point3f0((mat_*Vec4f0(new_pos..., 1.0f0))[1:3])

            elseif mouse.button == GLFW.MOUSE_BUTTON_2 #panning
                rt         = cam.right * dx * cam.translation_speed / 2
                ut         = -cam.up * dy * cam.translation_speed / 2
                new_lookat -= rt + ut
                new_pos    -= rt + ut
            end
        end

        #keyboard stuff
        if pressed(keyboard)
            if keyboard.button in WASD_KEYS
                new_pos, cam.lookat = wasd_event(new_pos, cam, keyboard)
            end
        end

        #scroll stuff no dxp
        new_forward = forward(new_pos, cam.lookat)
        new_pos += Point3f0(new_forward * scroll_dy * cam.translation_speed * 5)
        zoom = norm(new_forward)
        cam.proj = projmat(w, h, cam, zoom)

        # update_viewmat
        u_forward = normalize(new_forward)
        cam.right = unitright(u_forward, cam.up)
        cam.up = unitup(u_forward, e.right)
        cam.view = lookatmat(new_pos, cam.lookat, cam.up)
        cam.projview = cam.proj * cam.view
        e[Spatial] = Spatial(new_pos, e.velocity)
    end
end

unitforward(position, lookat) = normalize(forward(position, lookat))
unitright(forward, up)        = normalize(right(forward, up))
unitup(forward, right)        = normalize(up(forward, right))

forward(position, lookat) = Vec3f0(lookat - position)
right(forward, up)        = cross(forward, up)
up(forward, right)        = cross(right, forward)

#maybe it would be better to make the eyepos up etc vectors already vec4 but ok
function wasd_event(position::Point3f0, cam::Camera3D, keyboard)
    #ok this is a bit hacky but fine
    # origlen = norm(position)
    button = keyboard.button
    new_lookat = cam.lookat
    if button == GLFW.KEY_A
        move = Point3f0(cam.translation_speed * 5 * cam.right)
        #the world needs to move in the opposite direction
        position   -= move
        new_lookat -= move
    end
    if button == GLFW.KEY_D
        move       = Point3f0(cam.translation_speed * 5 * cam.right)
        position   += move
        new_lookat += move
    end
    if button == GLFW.KEY_W
        move       = Point3f0(unitforward(position, cam.lookat) * 5 * cam.translation_speed)
        position   += move
        new_lookat += move
    end
    if button == GLFW.KEY_S
        move       = Point3f0(unitforward(position, cam.lookat) * 5 * cam.translation_speed)
        position   -= move
        new_lookat -= move
    end
    return position, new_lookat
end
