#version 330 core
layout(location = 0) in vec3 vertices;
layout(location = 1) in vec3 normals;
layout(location = 2) in vec4 color;
layout(location = 3) in mat4 modelmat;
layout(location = 4) in float  specpow;
layout(location = 5) in float  specint;

uniform mat4 projview;
out vec3 fragnormal;
out vec4 fragcolor;
out vec3 world_pos;
out float specInt;
out float specPow;

void main () {

    fragcolor = color;
    fragnormal = normalize((modelmat * vec4(normals, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(vertices, 1.0f)).xyz;
    gl_Position = projview * modelmat * vec4(vertices, 1.0f);
}
