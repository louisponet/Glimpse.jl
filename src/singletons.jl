import GLAbstraction: bind, unbind, draw

#TODO think about contexts
#TODO handle resizing properly
@component mutable struct Canvas
    name             :: Symbol
    area             :: Area{Int}
    native_window    :: GLFW.Window
    imgui_context    :: UInt
    background       :: Colorant{Float32,4}
    cursor_position  :: NTuple{2,Float64}
    scroll           :: NTuple{2,Float64}
    has_focus        :: Bool
    mouse_buttons    :: Tuple{GLFW.MouseButton,GLFW.Action,Int}
    keyboard_buttons :: Tuple{GLFW.Key,Int,GLFW.Action,Int}
    framebuffer_size :: NTuple{2,Int}

    function Canvas(name::Symbol, area, nw, background)
        ctx = convert(UInt, CImGui.GetCurrentContext())
        if ctx == 0
            ctx = convert(UInt, CImGui.CreateContext())
        else
            CImGui.DestroyContext(CImGui.GetCurrentContext())
            ctx = convert(UInt, CImGui.CreateContext())
        end
        ImGui_ImplGlfw_InitForOpenGL(nw, true)
        ImGui_ImplOpenGL3_Init(420)
        CImGui.Set_KeyMap(CImGui.GetIO(), CImGui.LibCImGui.ImGuiKey_Backspace,
                          GLFW.KEY_BACKSPACE)
        CImGui.Set_KeyMap(CImGui.GetIO(), CImGui.LibCImGui.ImGuiKey_Delete, GLFW.KEY_DELETE)

        obj = new(name, area, nw, ctx, background, (0.0, 0.0), (0.0, 0.0), true,
                  (GLFW.MOUSE_BUTTON_1, GLFW.RELEASE, 0),
                  (GLFW.KEY_UNKNOWN, 0, GLFW.RELEASE, 0), (0, 0))

        GLFW.SetCursorPosCallback(nw,
                                  (nw, x::Cdouble, y::Cdouble) -> begin
                                      obj.cursor_position = (x, y)
                                  end)

        GLFW.SetScrollCallback(nw,
                               (nw, xoffset::Cdouble, yoffset::Cdouble) -> begin
                                   obj.scroll = (obj.scroll[1] + xoffset,
                                                 obj.scroll[2] + yoffset)
                               end)

        GLFW.SetWindowFocusCallback(nw, (nw, focus::Bool) -> begin
                                        obj.has_focus = focus
                                    end)

        GLFW.SetMouseButtonCallback(nw,
                                    (nw, button::GLFW.MouseButton, action::GLFW.Action, mods::Cint) -> begin
                                        obj.mouse_buttons = (button, action, Int(mods))
                                    end)

        GLFW.SetKeyCallback(nw,
                            (nw, button::GLFW.Key, scancode::Cint, action::GLFW.Action, mods::Cint) -> begin
                                obj.keyboard_buttons = (button, Int(scancode), action,
                                                        Int(mods))
                            end)

        GLFW.SetFramebufferSizeCallback(nw,
                                        (nw, w::Cint, h::Cint) -> begin
                                            obj.framebuffer_size = (Int(w), Int(h))
                                        end)

        finalizer(free!, obj)
        return obj
    end
    # framebuffer::FrameBuffer # this will become postprocessing passes. Each pp has a
end

Base.size(area::Area) = (GeometryBasics.widths(area)...,)

function Canvas(name = :Glimpse; kwargs...)
    defaults = mergepop!(canvas_defaults(), kwargs)

    window_hints  = GLFW_DEFAULT_WINDOW_HINTS
    context_hints = GLFW.standard_context_hints(defaults[:major], defaults[:minor])

    area = defaults[:area]
    # if !isassigned(GLFW_context)
    # GLFW_context[] = GLFW.Window(name = string(name),
    window = GLFW.Window(; name = string(name),
                         resolution = (GeometryBasics.widths(area)...,),
                         debugging = defaults[:debugging], major = defaults[:major],
                         minor = defaults[:minor], windowhints = window_hints,
                         contexthints = context_hints, visible = false, focus = false,
                         fullscreen = defaults[:fullscreen], monitor = defaults[:monitor])

    GLFW.SwapInterval(0) # deactivating vsync seems to make everything quite a bit smoother

    background = defaults[:background]

    c = Canvas(name, area, window, background)
    return c
end

function make_current(c::Canvas)
    GLFW.MakeContextCurrent(c.native_window)
    return GLA.set_context!(c)
end

function expose(c::Canvas)
    make_current(c)
    GLFW.SetWindowShouldClose(c.native_window, false)
    return GLFW.ShowWindow(c.native_window)
end

function swapbuffers(c::Canvas)
    if c.native_window.handle == C_NULL
        warn("Native Window handle of canvas $(c.name) == C_NULL!")
        return
    end
    GLFW.SwapBuffers(c.native_window)
    return
end

function isopen(canvas::Canvas)
    canvas.native_window.handle == C_NULL && return false
    return GLFW.GetWindowAttrib(canvas.native_window, GLFW.VISIBLE) == 1
end

#Should this clear the context?
function close(c::Canvas)
    GLFW.HideWindow(c.native_window)
    return should_close!(c, false)
end

should_close!(c::Canvas, b) = GLFW.SetWindowShouldClose(c.native_window, b)

should_close(c::Canvas) = GLFW.WindowShouldClose(c.native_window)

function clear!(c::Canvas, color = c.background)
    glClearColor(color.r, color.g, color.b, color.alpha)
    # glClearColor(1,1,1,1)
    return glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
end

pollevents(c::Canvas) = GLFW.PollEvents()

waitevents(c::Canvas) = GLFW.WaitEvents()

function GLA.free!(c::Canvas)
    if GLA.is_current_context(c)
        GLFW.DestroyWindow(c.native_window)
        clear_context!()
    end
end

bind(c::Canvas, target = GL_FRAMEBUFFER) = glBindFramebuffer(target, 0)

draw(c::Canvas) = nothing

nativewindow(c::Canvas) = c.native_window

Base.size(canvas::Canvas) = size(canvas.area)
Base.size(canvas::Canvas, i::Int) = size(canvas.area)[i]

function Base.resize!(c::Canvas, wh::NTuple{2,Integer}, resize_window = false)
    resize!(GLA.context_framebuffer(), wh)
    return c.area = Area{Int}(0, 0, wh...)
end

callback_value(c::Canvas, cb::Symbol) = c.callbacks[cb][]

callback(c::Canvas, cb::Symbol) = c.callbacks[cb]

windowsize(canvas::Canvas) = GLFW.GetWindowSize(nativewindow(canvas))

set_background_color!(canvas::Canvas, color::Colorant) = canvas.background = convert(RGBA{Float32}, color)
set_background_color!(canvas::Canvas, color::NTuple)   = canvas.background = convert(RGBA{Float32}, color)

#---------------------DEFAULTS-------------------#

# canvas_defaults() = SymAnyDict(:area       => Area{Int}(0, 0, glfw_standard_screen_resolution()...),
function canvas_defaults()
    return SymAnyDict(:area       => Area{Int}(0, 0, 3840, 2160),
                      :background => RGBA(1.0f0), :depth      => GLA.Depth{Float32},
                      :callbacks  => standard_callbacks(), :debugging  => false,
                      :major      => 3, :minor      => 3, :clear      => true,
                      :hidden     => false, :visible    => true, :focus      => false,
                      :fullscreen => false, :monitor    => nothing)
end

@component struct FullscreenVao
    vao::VertexArray
end

function FullscreenVao()
    return FullscreenVao(VertexArray([BufferAttachmentInfo(:position, GLint(0),
                                                           Buffer(fullscreen_pos),
                                                           GEOMETRY_DIVISOR),
                                      BufferAttachmentInfo(:uv, GLint(1),
                                                           Buffer(fullscreen_uv),
                                                           GEOMETRY_DIVISOR)],
                                     GL_TRIANGLE_STRIP))
end

bind(v::FullscreenVao) = bind(v.vao)

draw(v::FullscreenVao) = draw(v.vao)

unbind(v::FullscreenVao) = unbind(v.vao)

# I'm not sure this is nice design idk
abstract type RenderTarget end

macro render_target(name)
    return esc(quote
                   @component struct $name <: RenderTarget
                       target     :: Union{FrameBuffer,Canvas}
                       background :: RGBAf0
                   end
               end)
end

@render_target IOTarget

bind(r::RenderTarget, args...) = bind(r.target, args...)

draw(r::RenderTarget, args...) = draw(r.target, args...)

clear!(r::RenderTarget, c = r.background) = clear!(r.target, c)

Base.size(r::RenderTarget) = size(r.target)

GLA.depth_attachment(r::RenderTarget, args...) = GLA.depth_attachment(r.target, args...)

GLA.color_attachment(r::RenderTarget, args...) = GLA.color_attachment(r.target, args...)

GLA.free!(r::RenderTarget) = free!(r.target)

Base.resize!(r::RenderTarget, args...) = resize!(r.target, args...)

@component @with_kw mutable struct TimingData
    time::Float64          = time()
    dtime::Float64         = 0.0
    frames::Int            = 0
    preferred_fps::Float64 = 60
    reversed::Bool         = false
    timer::TimerOutput     = TimerOutput()
end

abstract type RenderProgram end
 
macro render_program(name)
    return esc(quote
                   @component struct $name <: RenderProgram
                       program::GLA.Program
                   end
               end)
end

bind(p::RenderProgram) = bind(p.program)

unbind(p::RenderProgram) = unbind(p.program)

GLA.gluniform(p::RenderProgram, args...) = GLA.gluniform(p.program, args...)

function generate_buffers(p::RenderProgram, args...; kwargs...)
    return generate_buffers(p.program, args...; kwargs...)
end

@component @with_kw struct UpdatedComponents
    components::Vector{DataType} = DataType[]
end

Base.empty!(uc::UpdatedComponents) = empty!(uc.components)

Base.iterate(uc::UpdatedComponents, r...) = iterate(uc.components, r...)

Base.push!(uc::UpdatedComponents, t::T) where {T} = push!(uc.components, T)
Base.push!(uc::UpdatedComponents, t::DataType)                   = push!(uc.components, t)

function update_component!(uc::UpdatedComponents, ::Type{T}) where {T}
    if !in(T, uc.components)
        push!(uc, T)
    end
end
