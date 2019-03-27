#version 420
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;
layout(location = 2) in vec4 color;

uniform mat4 projview;
uniform mat4 modelmat;
uniform vec4 uniform_color;
uniform bool is_uniform;
out vec3 fragnormal;
out vec3 world_pos;
out vec4 fragcolor;

void main () {
    fragnormal = normalize((modelmat * vec4(normals, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(vertices, 1.0f)).xyz;
    gl_Position = projview * modelmat * vec4(vertices, 1.0f);
	if (is_uniform) {
		fragcolor = uniform_color;
	}
	else {
		fragcolor = color;
	} 
}
