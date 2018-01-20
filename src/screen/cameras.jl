
abstract type Camera{T} end
const Q = Quaternions # save some writing!

mutable struct OrthographicCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    view            ::Signal{Mat4{T}}
    projection      ::Signal{Mat4{T}}
    projectionview  ::Signal{Mat4{T}}
end

"""
Creates an orthographic camera with the pixel perfect plane in z == 0
Signals needed:
Dict(
    :window_size           => Signal(SimpleRectangle{Int}),
    :buttons_pressed       => Signal(Int[]),
    :mouse_buttons_pressed => Signal(Int[]),
    :mouseposition         => mouseposition, -> Panning
    :scroll_y              => Signal(0) -> Zoomig
)
"""
function OrthographicPixelCamera(
        inputs;
        fov=41f0, near=0.01f0, up=Vec3f0(0,1,0),
        translation_speed = Signal(1), theta = Signal(Vec3f0(0)), keep = Signal(true)
    )
    @materialize mouseposition, mouse_buttons_pressed, buttons_pressed, scroll = inputs
    left_ctrl     = Set([GLFW.KEY_LEFT_CONTROL])
    use_cam       = map(AND, const_lift(==, buttons_pressed, left_ctrl), keep)

    mouseposition = droprepeats(map(Vec2f0, mouseposition))
    left_pressed  = const_lift(pressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_LEFT)
    xytranslate   = dragged_diff(mouseposition, left_pressed, use_cam)

    ztranslate    = filterwhen(use_cam, 0f0, map(x->Float32(x[2]), scroll))

    trans = map(translationlift, xytranslate, ztranslate, translation_speed)
    OrthographicPixelCamera(
        theta, trans, Signal(up), Signal(fov), Signal(near),
        inputs[:window_area],
    )
end
#question: Why is this returning a perspective camera?
function OrthographicPixelCamera(
        theta, trans, up, fov_s, near_s, area_s
    )
    fov, near = Reactive.value(fov_s), Reactive.value(near_s)

    # lets calculate how we need to adjust the camera, so that it mapps to
    # the pixel of the window (area)
    area = Reactive.value(area_s)
    h = Float32(tan(fov / 360.0 * pi) * near)
    w_, h_ = area.w / 2f0, area.h / 2f0
    zoom = min(h_, w_) / h
    x, y = w_, h_
    eyeposition = Signal(Vec3f0(x, y, zoom))
    lookatvec   = Signal(Vec3f0(x, y, 0))
    far         = Signal(zoom * 10f0) # this should probably be not calculated
    # since there is no scene independant, well working far clip

    PerspectiveCamera(
        theta,
        trans,
        lookatvec,
        eyeposition,
        up,
        area_s,
        fov_s, # Field of View
        near_s,  # Min distance (clip distance)
        far, # Max distance (clip distance)
        Signal(GLAbstraction.ORTHOGRAPHIC)
    )
end

mutable struct PerspectiveCamera{T} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{Int}}
    nearclip        ::Signal{T}
    farclip         ::Signal{T}
    fov             ::Signal{T}
    view            ::Signal{Mat4{T}}
    projection      ::Signal{Mat4{T}}
    projectionview  ::Signal{Mat4{T}}
    eyeposition     ::Signal{Vec{3, T}}
    lookat          ::Signal{Vec{3, T}}
    up              ::Signal{Vec{3, T}}
    trans           ::Signal{Vec{3, T}}
    theta           ::Signal{Vec{3, T}}
    projectiontype  ::Signal{Projection}
end

"""
Creates a perspective camera from a dict of signals
Args:

inputs: Dict of signals, looking like this:
[
    :window_size            => Signal(Vec{2, Int}),
    :buttons_pressed        => Signal(Int[]),
    :mouse_buttons_pressed  => Signal(Int[]),
    :mouseposition          => mouseposition, -> Panning + Rotation
    :scroll_y               => Signal(0) -> Zoomig
]
eyeposition: Position of the camera
lookatvec: Point the camera looks at
"""
function PerspectiveCamera(
        inputs::Dict{Symbol,Any},
        eyeposition::Vec{3, T}, lookatvec::Vec{3, T};
        upvector = Vec3f0(0, 0, 1),
        keep=Signal(true), theta=nothing, trans=nothing
    ) where T
    lookat, eyepos = Signal(lookatvec), Signal(eyeposition)
    # TODO make this more elegant!
    _theta, _trans = default_camera_control(
        inputs, Signal(0.1f0), Signal(1f0), keep
    )
    theta = theta == nothing ? _theta : theta
    trans = trans == nothing ? _trans : trans
    farclip = map(eyepos, lookat) do a,b
        max(norm(b-a) * 5f0, 30f0)
    end
    minclip = map(eyepos, lookat) do a,b
        norm(b-a) * 0.007f0
    end
    PerspectiveCamera(
        theta,
        trans,
        lookat,
        eyepos,
        Signal(upvector),
        inputs[:window_area],
        Signal(41f0), # Field of View
        Signal(0.001f0),  # Min distance (clip distance)
        farclip # Max distance (clip distance)
    )
end

function PerspectiveCamera(
        area,
        eyeposition::Signal{Vec{3, T}}, lookatvec::Signal{Vec{3, T}}, upvector
    ) where T
    PerspectiveCamera(
        Signal(Vec3f0(0)),
        Signal(Vec3f0(0)),
        lookatvec,
        eyeposition,
        upvector,
        area,
        Signal(41f0), # Field of View
        Signal(0.1f0),  # Min distance (clip distance)
        Signal(50f0) # Max distance (clip distance)
    )
end

"""
Creates a perspective camera from signals, controlling the camera
Args:

`window_size`: Size of the window

fov: Field of View
nearclip: Near clip plane
farclip: Far clip plane
`theta`: rotation around camera axis
`trans`: translation in camera space (xyz are the camera axes)
`lookatposition`: point the camera looks at
`eyeposition`: the actual position of the camera (the lense, the \"eye\")
"""
function PerspectiveCamera(
        theta,
        trans::Signal{T},
        lookatposition::Signal{T},
        eyeposition::Signal{T},
        upvector::Signal{T},
        window_size,
        fov,
        nearclip,
        farclip,
        projectiontype = Signal(PERSPECTIVE)
    ) where T<:Vec3
    # we have three ways to manipulate the camera: rotation, lookat/eyeposition and translation
    positions = (eyeposition, lookatposition, upvector)

    zoomlen = map(norm, map(-, lookatposition, eyeposition))
    projectionmatrix = map(projection_switch,
        window_size, fov, nearclip,
        farclip, projectiontype, zoomlen
    )

    # create the vievmatrix with the help of the lookat function
    viewmatrix = map(lookat, eyeposition, lookatposition, upvector)
    projectionview = map(*, projectionmatrix, viewmatrix)

    preserve(map(translate_cam,
       trans, Signal(projectionmatrix), Signal(viewmatrix), Signal(window_size),
       Signal(projectiontype),  Signal(eyeposition), Signal(lookatposition),
       Signal(upvector)
    ))

    preserve(map(theta) do theta_v
        theta_v == Vec3f0(0) && return nothing #nothing to do!
        eyepos_v, lookat_v, up_v = map(value, positions)

        dir = normalize(eyepos_v - lookat_v)
        right_v = normalize(cross(up_v, dir))
        up_v  = normalize(cross(dir, right_v))

        rotation = rotate_cam(theta_v, right_v, Vec3f0(0, 0, sign(up_v[3])), dir)
        r_eyepos = lookat_v + rotation*(eyepos_v - lookat_v)
        r_up = normalize(rotation*up_v)
        push!(eyeposition, r_eyepos)
        push!(upvector, r_up)
    end)


    PerspectiveCamera{eltype(T)}(
        window_size,
        nearclip,
        farclip,
        fov,
        viewmatrix,
        projectionmatrix,
        projectionview,
        eyeposition, lookatposition, upvector,
        trans,
        theta,
        projectiontype
    )
end

mutable struct DummyCamera{T, IT} <: Camera{T}
    window_size     ::Signal{SimpleRectangle{IT}}
    view            ::Signal{Mat4{T}}
    projection      ::Signal{Mat4{T}}
    projectionview  ::Signal{Mat4{T}}
end

function DummyCamera(;
        window_size    = Signal(SimpleRectangle(-1, -1, 1, 1)),
        view           = Signal(eye(Mat4f0)),
        nearclip       = Signal(-10_000f0),
        farclip        = Signal(10_000f0),
        projection     = const_lift(orthographicprojection, window_size, nearclip, farclip),
        projectionview = const_lift(*, projection, view)
    )
    DummyCamera(window_size, view, projection, projectionview)
end

function Base.collect(camera::Camera, collected = Dict{Symbol, Any}())
    names = fieldnames(camera)
    for name in (:view, :projection, :projectionview, :eyeposition)
        if name in names
            collected[name] = getfield(camera, name)
        end
    end
    return collected
end

function default_camera_control(
        inputs, rotation_speed, translation_speed, keep = Signal(true)
    )
    @materialize mouseposition, mouse_buttons_pressed, scroll = inputs

    mouseposition = droprepeats(map(Vec2f0, mouseposition))
    left_pressed  = const_lift(pressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_LEFT)
    right_pressed = const_lift(pressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_RIGHT)
    xytheta       = dragged_diff(mouseposition, left_pressed, keep)
    xytranslate   = dragged_diff(mouseposition, right_pressed, keep)

    ztranslate    = filterwhen(keep, 0f0,
        map(last, scroll)
    )
    translate_theta(
        xytranslate, ztranslate, xytheta,
        rotation_speed, translation_speed
    )
end

function projection_switch(
        wh::SimpleRectangle,
        fov::T, near::T, far::T,
        projection::Projection, zoom::T
    ) where T<:Real
    aspect = T(wh.w/wh.h)
    h      = T(tan(fov / 360.0 * pi) * near)
    w      = T(h * aspect)
    projection == PERSPECTIVE && return frustum(-w, w, -h, h, near, far)
    h, w   = h*zoom, w*zoom
    orthographicprojection(-w, w, -h, h, near, far)
end

function to_worldspace(point::T, cam) where T <: StaticVector
    to_worldspace(
        point,
        Reactive.value(cam.projection) * Reactive.value(cam.view),
        T(widths(Reactive.value(cam.window_size)))
    )
end

function to_worldspace(
        p::StaticVector{N, T},
        projectionview::Mat4,
        cam_res::StaticVector
    ) where {N, T}
    VT = typeof(p)
    prj_view_inv = inv(projectionview)
    clip_space = T(4) * (VT(p) ./ VT(cam_res))
    pix_space = Vec{4, T}(
        clip_space[1],
        clip_space[2],
        T(0), w_component(p)
    )
    ws = prj_view_inv * pix_space
    ws # ./ ws[4]
end

"""
Takes a point and a camera and transforms it from mouse (imagespace) to world space
"""
function imagespace(pos, camera)
    # Setup transformation matrix
    pv = Reactive.value(camera.projection) * Reactive.value(camera.view)
    inv_pv = inv(pv)
    width, height = widths(Reactive.value(camera.window_size)) # get pixel resolution
    x, y = pos
    # transform to normalized device coordinates [-1, 1]
    device_space = Vec4f0(
        2 * (x / width)  - 1,
        2 * (y / height) - 1,
        0.0,
        1.0
    )
    pos = inv_pv * device_space
    Point2f0(pos[1], pos[2]) / pos[4]
end

function translate_cam(
        translate, proj, view, window_size, prj_type,
        eyepos_s, lookat_s, up_s,
    )
    translate == Vec3f0(0) && return nothing # nothing to do

    lookat, eyepos, up, prjt = map(value, (lookat_s, eyepos_s, up_s, prj_type))
    dir = eyepos - lookat
    dir_len = norm(dir)
    cam_res = Vec2f0(widths(Reactive.value(window_size)))

    zoom, x, y = translate
    zoom *= 0.1f0 * dir_len
    if prjt != PERSPECTIVE
        x, y = to_worldspace(Vec2f0(x, y), Reactive.value(proj) * Reactive.value(view), cam_res)
    else
        x, y = (Vec2f0(x, y) ./ cam_res) .* dir_len
    end
    dir_norm = normalize(dir)
    right = normalize(cross(dir_norm, up))
    zoom_trans = dir_norm*zoom
    side_trans = right * (-x) + normalize(up) * y
    push!(eyepos_s, eyepos + side_trans + zoom_trans)
    push!(lookat_s, lookat + side_trans)
    nothing
end

function rotate_cam(
        theta::Vec{3, T},
        cam_right::Vec{3,T}, cam_up::Vec{3,T}, cam_dir::Vec{3, T}
    ) where T
    rotation = one(Q.Quaternion{T})
    # first the rotation around up axis, since the other rotation should be relative to that rotation
    if theta[1] != 0
        rotation *= Q.qrotation(cam_up, theta[1])
    end
    # then right rotation
    if theta[2] != 0
        rotation *= Q.qrotation(cam_right, theta[2])
    end
    # last rotation around camera axis
    if theta[3] != 0
        rotation *= Q.qrotation(cam_dir, theta[3])
    end
    rotation
end

"""
Centers the camera on a list of render objects
"""
function center!(camera::PerspectiveCamera, renderlist::Vector; border = 0)
    bb = renderlist_boundingbox(renderlist)
    bb = AABB(minimum(bb) .- border, widths(bb) .+ 2border)
    center!(camera, bb)
end

"""
Centers a camera onto a boundingbox
"""
function center!(camera::PerspectiveCamera, bb::AABB)
    width        = widths(bb)
    half_width   = width/2f0
    lower_corner = minimum(bb)
    middle       = maximum(bb) - half_width
    if Reactive.value(camera.projectiontype) == ORTHOGRAPHIC
        area, fov, near, far = map(value,
            (camera.window_size, camera.fov, camera.nearclip, camera.farclip)
        )
        aspect = Float32(area.w/area.h)
        h = Float32(tan(fov / 360.0 * pi) * near)
        w = h * aspect
        w_, h_, _ = half_width
        zoom = Vec2f0(w_, h_)./Vec2f0(w,h)
        x, y, _ = middle
        push!(camera.eyeposition, Vec3f0(x, y, maximum(zoom)))
        push!(camera.lookat, Vec3f0(x, y, 0))
        push!(camera.up, Vec3f0(0,1,0))
    else
        push!(camera.lookat, middle)
        neweyepos = middle + (width*1.2f0)
        push!(camera.eyeposition, neweyepos)
        push!(camera.up, Vec3f0(0,0,1))
        push!(camera.nearclip, 0.1f0 * norm(widths(bb)))
        push!(camera.farclip, 3f0 * norm(widths(bb)))
    end
    return
end

"""
Centers the camera(=:perspective) on all render objects in `window`
"""
function center!(window, camera::Symbol = :perspective; border = 0)
    rl = robj_from_camera(window, camera)
    center!(window.cameras[camera], rl, border = border)
end
