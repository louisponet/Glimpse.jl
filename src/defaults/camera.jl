const perspective_defaults = Dict{Symbol, Any}()
const orthographic_defaults = Dict{Symbol, Any}()

function setup_defaults(camkind::CamKind)
    t = Dict{Symbol, Any}()
    t[:eyepos] = Vec3(0f0, -1f0, 0f0)
    t[:lookat] = Vec3(0f0,  0f0, 0f0)
    t[:up]     = Vec3(0f0,  0f0, 1f0)
    t[:right]  = Vec3(1f0,  0f0, 0f0)
    t[:area] = Area(0,0,standard_screen_resolution()...)

    if camkind == perspective || camkind == orthographic
        t[:fov] = 42.0f0
        t[:near]= 0.1f0
        t[:far] = 100.0f0
        t[:rotation_speed] = 0.01f0
        t[:translation_speed] = 0.19f0
        global orthographic_defaults = t
        global perspective_defaults  = t
    elseif camkind == pixel
        t[:fov] = 0.0f0

        t[:near]= 0f0
        t[:far] = 0f0
        t[:rotation_speed] = 0f0
        t[:translation_speed] = 0f0
    end
end

function merge_defaults(x::CamKind; overrides...)
    if x == orthographic
        if isempty(orthographic_defaults)
            setup_defaults(orthographic)
        end
        merge(orthographic_defaults, overrides)
    elseif x == perspective
        if isempty(perspective_defaults)
            setup_defaults(perspective)
        end
        merge(perspective_defaults, overrides)
    end
end

function mergepop_defaults!(x::CamKind; overrides...)
    if x == orthographic
        if isempty(orthographic_defaults)
            setup_defaults(orthographic)
        end
        mergepop!(orthographic_defaults, overrides)
    elseif x == perspective
        if isempty(perspective_defaults)
            setup_defaults(perspective)
        end
        mergepop!(perspective_defaults, overrides)
    end
end
