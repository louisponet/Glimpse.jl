
using Base.RefValue
const screen_id_counter = RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_screen_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]

mutable struct Screen
    name      ::Symbol
    id        ::Int
    area      ::Area
    canvas    ::Canvas
    parent    ::Union{Screen, Void}
    children  ::Vector{Screen}
    callbacks ::Dict{Symbol, Any}
    hidden    ::Bool # if window is hidden. Will not render
    function Screen(name      ::Symbol,
                    area      ::Area, 
                    canvas    ::Canvas,
                    parent    ::Union{Screen, Void},
                    children  ::Vector{Screen},
                    callbacks ::Dict{Symbol, Any},
                    hidden    ::Bool)
        return new(name, new_screen_id(), area, canvas, parent, children, callbacks, hidden)
    end
end
function Screen(name = "GLider", area=Area(0, 0, standard_screen_resolution()...), background=RGBA(1.0f0);
                callbacks = standard_callbacks(),
                hidden    = false,
                canvas_kwargs...)
    canvas = Canvas(name, 1, area, background; canvas_kwargs...)
    callback_dict = register_callbacks(canvas.native_window, standard_callbacks())
    return Screen(Symbol(name), area, canvas, nothing, Screen[], callback_dict, hidden) 
end
Screen(name::String, resolution::Tuple{Int, Int}, args...;kwargs...) = Screen(name, Area(0, 0, resolution...), args...; kwargs...)

Base.isopen(screen::Screen) = isopen(screen.canvas)
clearcanvas!(s::Screen) = clear!(s.canvas)

focus(s::Screen)        = make_current(s.canvas)
bind(s::Screen)         = bind(s.canvas)
nativewindow(s::Screen) = nativewindow(s.canvas)
swapbuffers(s::Screen)  = swapbuffers(s.canvas)
pollevents(s::Screen)   = pollevents(s.canvas)
waitevents(s::Screen)   = waitevents(s.canvas)

destroy!(s::Screen)     = destroy!(s.canvas)

callback(s::Screen, cb::Symbol) = s.callbacks[cb][]

function update!(s::Screen)
    s.area = resize!(s,callback(s,:window_size))
end

function Base.resize!(s::Screen, w::Int, h::Int, resize_window=false)
    s.area = resize!(s.canvas, w, h, resize_window)
end
