#Came from GLAbstraction/GLCamera.jl

is_same_id(id_index, id::Int) = id_index.id == id
is_same_id(id_index, robj::RenderObject) = id_index.id == robj.id
is_same_id(id_index, ids::Tuple) = id_index.id in ids

"""
get's the boundingbox of a render object.
needs value, because boundingbox will always return a boundingbox signal
"""
signal_boundingbox(robj) = Reactive.value(boundingbox(robj))

"""
Calculates union boundingbox of all elements in renderlist
(Can't do ::Vector{RenderObject{T}}, because t is not always the same)
"""
function renderlist_boundingbox(renderlist::Vector)
    renderlist = filter(x-> x != nothing, renderlist)
    isempty(renderlist) && return AABB(Vec3f0(NaN), Vec3f0(0)) # nothing to do here
    robj1 = first(renderlist)
    bb = Reactive.value(robj1[:model])*signal_boundingbox(robj1)
    for elem in renderlist[2:end]
        bb = union(Reactive.value(elem[:model])*signal_boundingbox(elem), bb)
    end
    bb
end