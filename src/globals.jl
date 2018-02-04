import GLAbstraction: current_context, is_current_context, exists_context, clear_context!, set_context!
#Overloads for GLAbstraction.context
const global_context = Base.RefValue{Canvas}()
current_context() = global_context[]
is_current_context(x) = x == global_context[]
function set_context!(x)
    global_context[] = x
end
function exists_context()
    try
        global_context[]
        return true
    catch
        return false
    end
end
function clear_context!()
    global_context = Base.RefValue{Canvas}()
end
