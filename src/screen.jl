import ColorTypes: Colorant
import GLAbstraction: free!, bind, clear!

const screen_id_counter = Base.RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_screen_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]

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

isopen(screen::Screen)        = isopen(screen.canvas)
close(screen::Screen)         = (close.(screen.children); close(screen.canvas))

clear!(s::Screen)       = clear!(s.canvas)

focus(s::Screen)              = make_current(s.canvas)
GLAbstraction.bind(s::Screen) = GLAbstraction.bind(s.canvas)
nativewindow(s::Screen)       = nativewindow(s.canvas)
swapbuffers(s::Screen)        = swapbuffers(s.canvas)
pollevents(s::Screen)         = pollevents(s.canvas)
waitevents(s::Screen)         = waitevents(s.canvas)

function free!(s::Screen)
    free!(s.canvas)
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

windowsize(screen::Screen)                   = windowsize(screen.canvas)
set_background_color!(screen::Screen, color) = set_background_color!(screen.canvas, color)

should_close!(screen::Screen, b::Bool) = should_close!(screen.canvas, b)
should_close(screen::Screen) = should_close(screen.canvas)
