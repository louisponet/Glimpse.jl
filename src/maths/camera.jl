#Came from GLAbstraction/GLCamera.jl

function thetalift(xy, speed)
    Vec3f0(xy[1], -xy[2], 0f0).*speed
end
function translationlift(up_left, zoom, speed)
    Vec3f0(zoom, up_left[1], up_left[2]).*speed
end
function diff_vector(v0, p1)
    p0, diff = v0
    p1, p0-p1
end
function translate_theta(
        xytranslate, ztranslate, xytheta,
        rotation_speed, translation_speed
    )
    theta = map(thetalift, xytheta, rotation_speed)
    trans = map(translationlift, xytranslate, ztranslate, translation_speed)
    theta, trans
end

