const WASD_KEYS  = (GLFW.KEY_W, GLFW.KEY_A, GLFW.KEY_S, GLFW.KEY_D)
const SHIFT_KEYS = (GLFW.KEY_LEFT_SHIFT, GLFW.KEY_RIGHT_SHIFT)
const CTRL_KEYS  = (GLFW.KEY_LEFT_CONTROL, GLFW.KEY_RIGHT_CONTROL)

@component mutable struct Mouse
    x::Float32
    y::Float32
    dx::Float32
    dy::Float32
    scroll::NTuple{2, Float32}
    dscroll::NTuple{2, Float32}
    button::GLFW.MouseButton
    action::GLFW.Action
end

@component mutable struct Keyboard
    button::GLFW.Key
    modifiers::Int
    action::GLFW.Action
end

struct EventPoller <: System end

Overseer.requested_components(::EventPoller) = (Mouse, Keyboard, Canvas)

function Overseer.update(::EventPoller, m::AbstractLedger)
    c = singleton(m, Canvas)
    mouse = singleton(m, Mouse)
    keyboard = singleton(m, Keyboard)
    pollevents(c)

    x, y = c.cursor_position

    mouse_button         = c.mouse_buttons
    keyboard_button      = c.keyboard_buttons

    mouse.dx = x - mouse.x
    mouse.dy = y - mouse.y
    mouse.x  = x
    mouse.y  = y
    mouse.button = mouse_button[1]
    mouse.action = mouse_button[2] 
    mouse.dscroll = c.scroll .- mouse.scroll
    mouse.scroll  = c.scroll

    keyboard.button    = keyboard_button[1]
    keyboard.action   = keyboard_button[3]
    keyboard.modifiers = keyboard_button[4]
end

pressed(m::Mouse)     = m.action ∈ (GLFW.PRESS, GLFW.REPEAT)
pressed(k::Keyboard)  = k.action ∈ (GLFW.PRESS, GLFW.REPEAT)
released(m::Mouse)    = m.action == GLFW.RELEASE
released(k::Keyboard) = k.action == GLFW.RELEASE

# Mouse Picking Stuff
@component @with_kw mutable struct Selectable
    color::RGBf0 = RGBf0(0, 0, 0)
    selected::Bool = false
    color_modifier::Float32 = 1.3f0
end

struct IDColorGenerator <: System end

Overseer.requested_components(::IDColorGenerator) = (PolygonGeometry, Selectable)

function Overseer.update(::IDColorGenerator, m::AbstractLedger)
    sel = m[Selectable]
    i = length(sel)
    @inbounds for s in sel
        s.color = RGBf0(((i & 0x000000FF) >>  0)/ 255,((i & 0x0000FF00) >>  8)/255, ((i & 0x00FF0000) >> 16)/255)
        i+=1
    end
end

struct MousePicker <: System end

Overseer.requested_components(::MousePicker) = (Selectable, Camera3D, Spatial, UniformColor, Canvas, UpdatedComponents)

function Overseer.update(::MousePicker, m::AbstractLedger)
    ucolor             = m[UniformColor]
    bcolor             = m[BufferColor]
    canvas             = singleton(m, Canvas)
    updated_components = singleton(m, UpdatedComponents)
    mouse = singleton(m, Mouse)
    keyboard = singleton(m, Keyboard)
    wh                 = size(canvas)

    iofbo = singleton(m, IOTarget).target

    @inbounds if pressed(keyboard) && keyboard.button ∈ CTRL_KEYS && mouse.button == GLFW.MOUSE_BUTTON_1 && pressed(mouse)

        glFlush()
        bind(iofbo)
        glReadBuffer(GL_COLOR_ATTACHMENT1)

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
        dat = Ref{RGBf0}()
        # screenspace = (2 * cursor_position[1] / wh[1] - 1,  1-2*cursor_position[2]/wh[2])
        glReadPixels(mouse.x, wh[2]-mouse.y, 1, 1, GL_RGB, GL_FLOAT, dat)
        unbind(iofbo)
        selected_color = dat[]
        for e in @entities_in(m, Selectable)
            mod = e.color_modifier
            if isapprox(e.color, selected_color)
                was_selected = e.selected
                e.selected = true
                if !was_selected
                    if e in ucolor
                        o_c = ucolor[e].color
                        ucolor[e] = UniformColor(RGB(o_c.r * mod, o_c.g * mod, o_c.b * mod))
                        register_update(m, UniformColor)
                    elseif e in bcolor
                        bcolor[e].color .*= mod
                        register_update(m, BufferColor)
                    end
                end
            elseif !isapprox(e.color, selected_color)
                was_not_selected = e.selected
                e.selected = false
                if was_not_selected 
                    if e in ucolor
                        o_c = ucolor[e].color
                        ucolor[e] = UniformColor(RGB(o_c.r / mod, o_c.g / mod, o_c.b / mod))
                        register_update(m, UniformColor)
                    elseif e in bcolor
                        bcolor[e].color ./= mod
                        register_update(m, BufferColor)
                    end
                end
            end
        end
    end
end

mouse_to_screenspace(m::Mouse, c::Canvas) = (2 * m.x / size(c, 1) - 1,  1-2*m.y/size(c, 2))

struct Ray
    origin::Point3f0
    direction::Vec3f0
end

function Ray(m::Mouse, c::Canvas, camera::Camera3D, eye::Point3f0)
    screenspace = mouse_to_screenspace(m, c)
    ray_clip    = Vec4f0(screenspace..., -1.0, 1.0)
    cam_proj = camera.proj
    cam_view = camera.view
    ray_eye     = Vec4f0((inv(cam_proj) * ray_clip)[1:2]..., -1.0, 0.0)
    ray_dir     = normalize(Vec3f0((inv(cam_view) * ray_eye)[1:3]...))
    return Ray(eye, ray_dir)
end

struct Plane
    origin::Point3f0
    normal::Vec3f0
end

intersect(r::Ray, p::Plane) = 
    r.origin + r.direction * dot((p.origin - r.origin), p.normal)/(dot(r.direction, p.normal))
