#Came from GLWindow/core.jl

"""
Create a new rectangle with x,y == 0,0 while taking the widths from the original
Rectangle
"""
zeroposition(r::SimpleRectangle{T}) where {T} = SimpleRectangle(zero(T), zero(T), r.w, r.h)
