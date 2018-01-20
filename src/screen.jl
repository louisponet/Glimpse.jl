
using Base.RefValue
const screen_id_counter = RefValue(0)
# start from new and hope we don't display all displays at once.
# TODO make it clearer if we reached max num, or if we just created
# a lot of small screens and display them simultanously
new_screen_id() = (screen_id_counter[] = mod1(screen_id_counter[] + 1, 255); screen_id_counter[])[]

struct Screen
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

function Screen(name = "GLider", area=Area(0, 0, GLFW.standard_screen_resolution()...), background=RGBA(1.0f0);
                depth     = Depth{Float32},
                callbacks = standard_callbacks(),
                hidden    = false,
                canvas_kwargs...)
    canvas = Canvas(name, 1, area, depth, background; canvas_kwargs...)
    callback_dict = register_callbacks(canvas.native_window, callbacks)
    return Screen(Symbol(name), area, canvas, nothing, Screen[], callback_dict, hidden)
end

Screen(name::String, resolution::Tuple{Int, Int}, args...;kwargs...) = Screen(name, Area(0, 0, resolution...), args...; kwargs...)