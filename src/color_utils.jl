import ColorTypes: RGBA, Colorant
ColorTypes.RGBA(x::T) where T = RGBA{T}(x,x,x,x)
ColorTypes.RGBA{T}(x) where T = RGBA{T}(T(x),T(x),T(x),T(x))

Base.size(x::Type{Colorant}) = (length(x),)
Base.ndims(x::Type{Colorant}) = 1
