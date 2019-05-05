#version 420

layout (location = 0) in vec4 vertices;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec4 color;
uniform mat4 proj_view;
uniform mat4 modelmat;
uniform float xoffset;
out vec2 frag_uv;
out vec4 frag_color;
void main()
{
    frag_uv = uv;
    frag_color = color;
    gl_Position = vec4(vertices.x, vertices.y, 0.0, 1);
}


