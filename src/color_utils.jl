ColorTypes.RGBA(x::T) where T = RGBA{T}(x,x,x,x)
ColorTypes.RGBA{T}(x) where T = RGBA{T}(T(x),T(x),T(x),T(x))