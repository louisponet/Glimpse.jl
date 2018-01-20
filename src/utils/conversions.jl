#Came from GLAbstraction/GLUtils.jl
"""
Needed to match the lazy gl_convert exceptions.
    `Target`: targeted OpenGL type
    `x`: the variable that gets matched
"""
matches_target(::Type{Target}, x::T) where {Target, T} = applicable(gl_convert, Target, x) || T <: Target  # it can be either converted to Target, or it's already the target
matches_target(::Type{Target}, x::Signal{T}) where {Target, T} = applicable(gl_convert, Target, x)  || T <: Target
matches_target(::Function, x) = true
matches_target(::Function, x::Void) = false
export matches_target


signal_convert(T, y) = convert(T, y)
signal_convert(T1, y::T2) where {T2<:Signal} = map(convert, Signal(T1), y)
