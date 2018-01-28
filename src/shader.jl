import Transpiler: emit_vertex_shader, emit_fragment_shader, emit_geometry_shader
# import Sugar: getsource!
import GLAbstraction: Shader
import GLAbstraction: shadertype
import ModernGL: GL_COMPUTE_SHADER, GL_VERTEX_SHADER, GL_FRAGMENT_SHADER, GL_GEOMETRY_SHADER
#remember: gli is like an interface to gl methods that are used in GLSL

#for now i don't directly see why I would want to use Lazy stuff
function Shader(typ_func::Tuple{Symbol, Function}, arg_types::Tuple)
    typ, func = typ_func
    gltyp = shadertype(typ)

    if gltyp == GL_VERTEX_SHADER
        source, v_out = emit_vertex_shader(func, arg_types)
        return Shader(source, gltyp, typ)
    elseif gltyp == GL_FRAGMENT_SHADER
        return Shader(emit_fragment_shader(func, arg_types), gltyp, typ)
    elseif gltyp == GL_GEOMETRY_SHADER
        return Shader(emit_geometry_shader(func, arg_types), gltyp, typ)
    else
        error("Transpiling not implemented for Compute shaders!")
    end
end