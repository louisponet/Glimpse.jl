@inline function sleep_pessimistic(sleep_time)
    st = convert(Float64, sleep_time) - 0.002
    start_time = time()
    while (time() - start_time) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

function glenum2julia(x::UInt32)
    x == GL_FLOAT      && return f32
    x == GL_FLOAT_VEC3 && return Vec3f0
    x == GL_FLOAT_VEC4 && return Vec4f0
    x == GL_FLOAT_MAT2 && return Mat2f0
    x == GL_FLOAT_MAT3 && return Mat3f0
    x == GL_FLOAT_MAT4 && return Mat4f0

    x == GL_DOUBLE      && return f64
    x == GL_DOUBLE_VEC3 && return Vec3{f64}
    x == GL_DOUBLE_VEC4 && return Vec4{f64}
    x == GL_DOUBLE_MAT2 && return Mat2{f64}
    x == GL_DOUBLE_MAT3 && return Mat3{f64}
    x == GL_DOUBLE_MAT4 && return Mat4{f64}

    x == GL_INT       && return i32
    x == GL_INT_VEC2  && return Vec2{i32}
    x == GL_INT_VEC3  && return Vec3{i32}
    x == GL_INT_VEC4  && return Vec4{i32}

    x == GL_UNSIGNED_INT        && return u32
    x == GL_UNSIGNED_INT_VEC2   && return Vec2{u32}
    x == GL_UNSIGNED_INT_VEC3   && return Vec3{u32}
    x == GL_UNSIGNED_INT_VEC4   && return Vec4{u32}
end

function mergepop!(d1, d2)
    t = SymAnyDict()

    d = isempty(d2) ? SymAnyDict() : Dict(d2)
    for (key, val) in d1
        t[key] = pop!(d, key, val)
    end
    d2 = [d...]
    return t
end

function GLAbstraction.gluniform(loc::Integer, x::Mat4{Float32})
    glUniformMatrix4fv(loc, 1, GL_FALSE, reinterpret(Float32,[x]))
end
