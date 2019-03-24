#version 420
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;

uniform mat4 projview;
uniform mat4 modelmat;
out vec3 fragnormal;
out vec3 world_pos;


void main () {
    fragnormal = normalize((modelmat * vec4(normals, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(vertices, 1.0f)).xyz;
    gl_Position = projview * modelmat * vec4(vertices, 1.0f);
}
