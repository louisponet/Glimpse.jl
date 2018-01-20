#Came from GLAbstraction/GLUtils.jl
"""
Takes a dict and inserts defaults, if not already available.
The variables are made accessible in local scope, so things like this are possible:
gen_defaults! dict begin
    a = 55
    b = a * 2 # variables, like a, will get made visible in local scope
    c::JuliaType = X # `c` needs to be of type JuliaType. `c` will be made available with it's original type and then converted to JuliaType when inserted into `dict`
    d = x => GLType # OpenGL convert target. Get's only applied if `x` is convertible to GLType. Will only be converted when passed to RenderObject
    d = x => \"doc string\"
    d = x => (GLType, \"doc string and gl target\")
end
"""
macro gen_defaults!(dict, args)
    args.head == :block || error("second argument needs to be a block of form
    begin
        a = 55
        b = a * 2 # variables, like a, will get made visible in local scope
        c::JuliaType = X # c needs to be of type JuliaType. c will be made available with it's original type and then converted to JuliaType when inserted into data
        d = x => GLType # OpenGL convert target. Get's only applied if x is convertible to GLType. Will only be converted when passed to RenderObject
    end")
    tuple_list = args.args
    dictsym = gensym()
    return_expression = Expr(:block)
    push!(return_expression.args, :($dictsym = $dict)) # dict could also be an expression, so we need to asign it to a variable at the beginning
    push!(return_expression.args, :(gl_convert_targets = get!($dictsym, :gl_convert_targets, Dict{Symbol, Any}()))) # exceptions for glconvert.
    push!(return_expression.args, :(doc_strings = get!($dictsym, :doc_string, Dict{Symbol, Any}()))) # exceptions for glconvert.
    # @gen_defaults can be used multiple times, so we need to reuse gl_convert_targets if already in here
    for (i, elem) in enumerate(tuple_list)
        if Base.is_linenumber(elem)
            push!(return_expression.args, elem)
            continue
        end
        opengl_convert_target = :() # is optional, so first is an empty expression
        convert_target        = :() # is optional, so first is an empty expression
        doc_strings           = :()
        if elem.head == :(=)
            key_name, value_expr = elem.args
            if isa(key_name, Expr) && key_name.head == :(::) # we need to convert to a julia type
                key_name, convert_target = key_name.args
                convert_target = :(GLAbstraction.signal_convert($convert_target, $key_name))
            else
                convert_target = :($key_name)
            end
            key_sym = Expr(:quote, key_name)
            if isa(value_expr, Expr) && value_expr.head == :call && value_expr.args[1] == :(=>)  # we might need to insert a convert target
                value_expr, target = value_expr.args[2:end]
                undecided = []
                if isa(target, Expr)
                    undecided = target.args
                else
                    push!(undecided, target)
                end
                for elem in undecided
                    isa(elem, Expr) && continue #
                    if isa(elem, AbstractString) # only docstring
                        doc_strings = :(doc_strings[$key_sym] = $elem)
                    elseif isa(elem, Symbol)
                        opengl_convert_target = quote
                            if matches_target($elem, $key_name)
                                gl_convert_targets[$key_sym] = $elem
                            end
                        end
                    end
                end
            end
            expr = quote
                $key_name = if haskey($dictsym, $key_sym)
                    $dictsym[$key_sym]
                else
                    $value_expr # in case that evaluating value_expr is expensive, we use a branch instead of get(dict, key, default)
                end
                $dictsym[$key_sym] = $convert_target
                $opengl_convert_target
                $doc_strings
            end
            push!(return_expression.args, expr)
        else
            error("all nodes need to be of form a = b OR a::Type = b OR a = b => Type, where a needs to be a var and b any expression. Found: $elem")
        end
    end
    #push!(return_expression.args, :($dictsym[:gl_convert_targets] = gl_convert_targets)) #just pass the targets via the dict
    push!(return_expression.args, :($dictsym)) #return dict
    esc(return_expression)
end


#Came from GLAbstraction/GLTexture.jl


function set_packing_alignment(a) # at some point we should specialize to array/ptr a
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)
end