#Came from GLAbstraction/GLUtils.jl
makesignal(s::Signal) = s
makesignal(v) = Signal(v)

@inline const_lift(f::Union{DataType, Type, Function}, inputs...) = map(f, map(makesignal, inputs)...)
export const_lift

