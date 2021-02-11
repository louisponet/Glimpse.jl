#version 420
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;
layout(location = 2) in vec3 color;

uniform mat4 projview;
uniform mat4 modelmat;
uniform vec3 object_id_color;
uniform float alpha;

out vec3 fragnormal;
out vec3 world_pos;
out vec4 fragcolor;
out vec3 id_color;

void main () {
	id_color = object_id_color;
    fragnormal = normalize((modelmat * vec4(normals, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(vertices, 1.0f)).xyz;
    gl_Position = projview * modelmat * vec4(vertices, 1.0f);
	fragcolor = vec4(color, alpha);
}
