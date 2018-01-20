import GLAbstraction: Depth, DepthStencil, DepthFormat, FrameBuffer
import GLAbstraction: bind, unbind, clear!
#TODO Framebuffer context

function canvas_fbo(area::Area, depthformat::Type{<:DepthFormat} = Depth{Float32}, color = RGBA(0.0f0,0.0f0,0.0f0,1.0f0))
    fbo = FrameBuffer((area.w, area.h), (RGBA{N0f8}, depthformat))
    clear!(fbo, color)
    return fbo
end

struct Canvas
    name::Symbol
    id::Int
    area::Area
    native_window::GLFW.Window
    framebuffer::FrameBuffer
end
function Canvas(name, id, area, depth::Type{<:DepthFormat} = Depth{Float32}, background::Colorant = RGBA(0.0f0);
                fbo_color = RGBA(0.0f0,0.0f0,0.0f0,1.0f0),
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

    nw = GLFW.Window(name,
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
    end
    glClear(GL_FRAMEBUFFER)
    fbo = canvas_fbo(area, depth, fbo_color)
    return Canvas(Symbol(name), id, area, nw, fbo)
end