#Came from GLAbstraction/GLCamera.jl
pressed(keys, key) = key in keys
singlepressed(keys, key) = length(keys) == 1 && first(keys) == key

mouse_dragg(v0, args) = mouse_dragg(v0..., args...)
function mouse_dragg(
        started::Bool, waspressed::Bool, startpoint, diff,
        ispressed::Bool, position, start_condition::Bool
    )
    started && ispressed && return (true, ispressed, startpoint, position-startpoint)
    if !started && !waspressed && ispressed && start_condition
        return (true, true, position, Vec2f0(0))
    end
    (false, ispressed, Vec2f0(0), Vec2f0(0))
end

mouse_dragg_diff(v0, args) = mouse_dragg_diff(v0..., args...)
function mouse_dragg_diff(
        started::Bool, waspressed, position0, diff,
        ispressed::Bool, position, start_condition::Bool
    )
    if !started && ispressed && (start_condition && !waspressed)
        return (true, ispressed, position, Vec2f0(0))
    end
    started && ispressed && return (true, ispressed, position, position0-position)
    (false, ispressed, Vec2f0(0), Vec2f0(0))
end

function dragged(mouseposition, key_pressed, start_condition = true)
    v0 = (false, false, Vec2f0(0), Vec2f0(0))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = foldp(mouse_dragg, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg = map(last, dragg_sig)
    dragg_diff = filterwhen(is_dragg, Reactive.value(dragg), dragg)
    dragg_diff
end
function dragged_diff(mouseposition, key_pressed, start_condition=true)
    v0 = (false, false, Vec2f0(0), Vec2f0(0))
    args = const_lift(tuple, key_pressed, mouseposition, start_condition)
    dragg_sig = foldp(mouse_dragg_diff, v0, args)
    is_dragg = map(first, dragg_sig)
    dragg_diff = map(last, dragg_sig)
    dragg_diff
end

"""
Transforms a mouse drag into a selection from drag start to drag end
"""
function drag2selectionrange(v0, selection)
    mousediff, id_start, current_id = selection
    if mousediff != Vec2f0(0) # Mouse Moved
        if current_id[1] == id_start[1]
            return min(id_start[2],current_id[2]):max(id_start[2],current_id[2])
        end
    else # if mouse did not move while dragging, make a single point selection
        if current_id.id == id_start.id
            return current_id.index:0 # this is the type stable way of indicating, that the selection is between currend_index
        end
    end
    v0
end

"""
Returns a boolean signal indicating if the mouse hovers over `robj`
"""
function is_hovering(robj::RenderObject, window)
    droprepeats(const_lift(is_same_id, window.inputs[:mouse_hover], robj))
end

"""
Returns two signals, one boolean signal if clicked over `robj` and another
one that consists of the object clicked on and another argument indicating that it's the first click
"""
function clicked(robj::RenderObject, button::MouseButton, window)
    @materialize mouse_hover, mousebuttonspressed = window.inputs
    clicked_on = const_lift(mouse_hover, mousebuttonspressed) do mh, mbp
        mh.id == robj.id && in(button, mbp)
    end
    clicked_on_obj = keepwhen(clicked_on, false, clicked_on)
    clicked_on_obj = const_lift((mh, x)->(x,robj,mh), mouse_hover, clicked_on)
    clicked_on, clicked_on_obj
end

"""
returns a signal which becomes true whenever there is a doublecklick
"""
function doubleclick(mouseclick, threshold::Real)
    ddclick = foldp((time(), Reactive.value(mouseclick), false), mouseclick) do v0, mclicked
        t0, lastc, _ = v0
        t1 = time()
        isclicked = (length(mclicked) == 1 &&
            length(lastc) == 1 &&
            first(lastc) == first(mclicked) &&
            t1-t0 < threshold
        )
        return (t1, mclicked, isclicked)
    end
    dd = const_lift(last, ddclick)
    return dd
end