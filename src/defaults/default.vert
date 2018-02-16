#version 410
layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 color;

uniform mat4 projview;
uniform mat4 modelmat;
out vec3 fragnormal;
out vec3 fragcolor;
out vec3 world_pos;


void main () {

    fragcolor = color;
    fragnormal = normalize((modelmat * vec4(normal, 0.0f)).xyz);
    world_pos  = (modelmat * vec4(position, 1.0f)).xyz;
    // gl_Position = projview  * vec4(position,1.0f);
    gl_Position = projview * modelmat * vec4(position, 1.0f);
}
