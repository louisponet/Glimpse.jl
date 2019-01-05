import ColorTypes: Colorant
import GLAbstraction: free!, bind

const screen_id_counter = Base.RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_screen_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]

mutable struct Screen
    name      ::Symbol
    id        ::Int
    area      ::Area
    canvas    ::Union{Canvas, Nothing}
    background::Colorant
    parent    ::Union{Screen, Nothing}
    children  ::Vector{Screen}
    hidden    ::Bool # if window is hidden. Will not render
    function Screen(name      ::Symbol,
                    area      ::Area,
                    canvas    ::Canvas,
                    background::Colorant,
                    parent    ::Union{Screen, Nothing},
                    children  ::Vector{Screen},
                    hidden    ::Bool)
        id = new_screen_id()
        canvas.id = id
        return new(name, id, area, canvas,background, parent, children, hidden)
    end
end
function Screen(name = :Glimpse; area=Area(0, 0, standard_screen_resolution()...),
                                 background=RGBA(1.0f0),
                                 hidden    = false,
                                 canvas_kwargs...)
    canvas = Canvas(name, 1; area = area, hidden = hidden, background = background, canvas_kwargs...)
    if !hidden
        make_current(canvas)
    end
    return Screen(name, area, canvas, background, nothing, Screen[], hidden)
end
Screen(name::Symbol, resolution::Tuple{Int, Int}, args...; kwargs...) = Screen(name, area=Area(0, 0, resolution...), args...; kwargs...)

Base.isopen(screen::Screen) = isopen(screen.canvas)
clearcanvas!(s::Screen) = clear!(s.canvas)

focus(s::Screen)        = make_current(s.canvas)
GLAbstraction.bind(s::Screen)    = GLAbstraction.bind(s.canvas)
nativewindow(s::Screen) = nativewindow(s.canvas)
swapbuffers(s::Screen)  = swapbuffers(s.canvas)
pollevents(s::Screen)   = pollevents(s.canvas)
waitevents(s::Screen)   = waitevents(s.canvas)

function free!(s::Screen)
    s.canvas = destroy!(s.canvas)
    return s
end

callback(s::Screen, cb::Symbol) = callback(s.canvas, cb)

function update!(s::Screen)
    s.area = resize!(s,callback(s,:window_size))
end

function Base.resize!(s::Screen, w::Int, h::Int, resize_window=false)
    s.area = resize!(s.canvas, w, h, resize_window)
end

#todo standardcallbacks!
function raise(s::Screen; canvas_kwargs...)
    s.canvas = s.canvas == nothing ? Canvas(s.name, 1; area = s.area, background = s.background, canvas_kwargs...) : s.canvas
    if !s.hidden
        make_current(s.canvas)
    end
    return s
end

windowsize(screen::Screen) = windowsize(screen.canvas)
