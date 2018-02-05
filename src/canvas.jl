import GLAbstraction: Depth, DepthStencil, DepthFormat, FrameBuffer, AbstractContext
import GLAbstraction: unbind, swapbuffers
import GLFW: standard_window_hints, SAMPLES, DEPTH_BITS, ALPHA_BITS, RED_BITS, GREEN_BITS, BLUE_BITS, STENCIL_BITS, AUX_BUFFERS
#TODO Framebuffer context
"""
Standard window hints for creating a plain context without any multisampling
or extra buffers beside the color buffer
"""
function standard_window_hints()
	[
		(SAMPLES,      0),
		(DEPTH_BITS,   32),

		(ALPHA_BITS,   8),
		(RED_BITS,     8),
		(GREEN_BITS,   8),
		(BLUE_BITS,    8),

		(STENCIL_BITS, 0),
		(AUX_BUFFERS,  0)
	]
end

function canvas_fbo(area::Area, depthformat::Type{<:DepthFormat} = Depth{Float32}, color = RGBA(0.0f0,0.0f0,0.0f0,1.0f0))
    fbo = FrameBuffer((area.w, area.h), (RGBA{N0f8}, depthformat))
    clear!(fbo, color)
    return fbo
end

standard_screen_resolution() = div.(GLFW.GetMonitorPhysicalSize(GLFW.GetPrimaryMonitor()),1)

mutable struct Canvas <: AbstractContext
    name          ::Symbol
    id            ::Int
    area          ::Area
    native_window ::GLFW.Window
    background    ::Colorant
    callbacks     ::Dict{Symbol, Any}
    # framebuffer::FrameBuffer # this will become postprocessing passes. Each pp has a
end
function Canvas(name, id,  area=Area(0, 0, standard_screen_resolution()...), background=RGBA(1.0f0), depth::Type{<:DepthFormat} = Depth{Float32};
                callbacks = standard_callbacks(),
                # fbo_color = background,
                debugging = false,
                major = 3,
                minor = 3,# this is what GLVisualize needs to offer all features
                windowhints = GLFW.standard_window_hints(),
                contexthints = GLFW.standard_context_hints(major, minor),
                clear = true,
                hidden = false,
                visible = true,
                focus = false,
                fullscreen = false,
                monitor = nothing)

    nw = GLFW.Window(String(name),
                     resolution = (area.w,area.h),
                     debugging = debugging,
                     major = major,
                     minor = minor,
                     windowhints = windowhints,
                     contexthints=contexthints,
                     visible = visible,
                     focus = focus,
                     fullscreen = fullscreen,
                     monitor = monitor)
    GLFW.SwapInterval(0) # deactivating vsync seems to make everything quite a bit smoother
    if typeof(background) <: RGBA
        glClearColor(background.r, background.g, background.b, background.alpha)
    elseif typeof(background) <: RGB
        glClearColor(background.r, background.g, background.b, GLfloat(1))
        background = RGBA(background)
    end
    glClear(GL_COLOR_BUFFER_BIT)
    callback_dict = register_callbacks(nw, callbacks)
    # fbo = canvas_fbo(area, depth, fbo_color)
    # return Canvas(Symbol(name), id, area, nw, background, fbo)
    return Canvas(name, id, area, nw, background, callback_dict)
end

function swapbuffers(c::Canvas)
    if c.native_window.handle == C_NULL
        warn("Native Window handle of canvas $(c.name) == C_NULL!")
        return
    end
    GLFW.SwapBuffers(c.native_window)
    return
end

function make_current(c::Canvas)
    GLFW.MakeContextCurrent(c.native_window)
    set_context!(c)
end

function Base.isopen(canvas::Canvas)
    canvas.native_window.handle == C_NULL && return false
    !GLFW.WindowShouldClose(canvas.native_window)
end
function Base.clear!(c::Canvas)
    glClearColor(c.background.r, c.background.b, c.background.g, c.background.alpha)
    # glClearColor(1,1,1,1)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
end

pollevents(c::Canvas) = GLFW.PollEvents()
waitevents(c::Canvas) = GLFW.WaitEvents()

function destroy!(c::Canvas)
    if is_current_context(c)
        GLFW.DestroyWindow(c.native_window)
        clear_context!()
        return
    else
        return c
    end
end
Base.bind(c::Canvas)       = glBindFramebuffer(GL_FRAMEBUFFER, 0)
nativewindow(c::Canvas) = c.native_window

function Base.resize!(c::Canvas, w::Int, h::Int, resize_window=false)
    nw = c.native_window
    area = c.area
    f = scaling_factor(c)
    # There was some performance issue with round.(Int, SVector) - not sure if resolved.
    wf, hf = Int.(round.(f .* Vec(w, h)))
    c.area = Area(area.x, area.y, wf, hf)
    if resize_window
        GLFW.SetWindowSize(c.native_window, wf, hf)
    end
    return c.area
end

"""
On OSX retina screens, the window size is different from the
pixel size of the actual framebuffer. With this function we
can find out the scaling factor.
"""
function scaling_factor(window::Vec{2, Int}, fb::Vec{2, Int})
    (window[1] == 0 || window[2] == 0) && return Vec{2, Float64}(1.0)
    Vec{2, Float64}(fb) ./ Vec{2, Float64}(window)
end
function scaling_factor(c::Canvas)
    w, fb = GLFW.GetWindowSize(c.native_window), GLFW.GetFramebufferSize(c.native_window)
    scaling_factor(Vec{2, Int}(w), Vec{2, Int}(fb))
end

"""
Correct OSX scaling issue and move the 0,0 coordinate to left bottom.
"""
function corrected_coordinates(
        window_size::Vec{2,Int},
        framebuffer_width::Vec{2,Int},
        mouse_position::Vec{2,Float64}
    )
    s = scaling_factor(window_size.value, framebuffer_width.value)
    Vec{2,Float64}(mouse_position[1], window_size.value[2] - mouse_position[2]) .* s
end

callback(c::Canvas, cb::Symbol) = c.callbacks[cb][]
