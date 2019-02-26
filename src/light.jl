"Darkens the light by the percentage"
function darken!(light::Light{T}, percentage) where T
	val = (100-percentage)/100
    light.diffuse  *= convert(T, val)
    light.specular *= convert(T, val)
    light.ambient  *= convert(T, val)
end

function lighten!(light::Light{T}, percentage) where T
	val = (100+percentage)/100
    light.diffuse  *= convert(T, val)
    light.specular *= convert(T, val)
    light.ambient  *= convert(T, val)
end
