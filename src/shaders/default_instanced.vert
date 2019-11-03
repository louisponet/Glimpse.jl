#version 420
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;
layout(location = 2) in vec3 color;
layout(location = 3) in float alpha;
layout(location = 4) in float specpow;
layout(location = 5) in float specint;
layout(location = 6) in vec3 object_id_color;
layout(location = 7) in mat4 modelmat;

uniform mat4 projview;

out vec3 fragnormal;
out vec4 fragcolor;
out vec3 world_pos;
out float specInt;
out float specPow;
out vec3 id_color;

void main () {
	id_color = object_id_color;
    fragcolor = vec4(color, alpha);
    specInt = specint;
    specPow = specpow;
    fragnormal = normalize((modelmat * vec4(normals, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(vertices, 1.0f)).xyz;
    gl_Position = projview * modelmat * vec4(vertices, 1.0f);
}
