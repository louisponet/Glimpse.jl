#version 410

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 color;

uniform mat4 proj;
uniform mat4 view;
out vec3 outcolor;

void main()
{
    outcolor = color;
    gl_Position = proj*view*vec4(position, 1.0);
}
