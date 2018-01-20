#Came from GLAbstraction/GLUtils.jl, used in Makie and GLVisualize
"""
Style Type, which is used to choose different visualization/editing styles via multiple dispatch
Usage pattern:
visualize(::Style{:Default}, ...)           = do something
visualize(::Style{:MyAwesomeNewStyle}, ...) = do something different
"""
struct Style{StyleValue}
end

Style(x::Symbol) = Style{x}()
Style() = Style{:Default}()
mergedefault!(style::Style{S}, styles, customdata) where {S} = merge!(copy(styles[S]), Dict{Symbol, Any}(customdata))
macro style_str(string)
    Style{Symbol(string)}
end
export @style_str