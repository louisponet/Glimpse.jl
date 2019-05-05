#version 420

layout (location = 0) in vec4 offsets_uv;
uniform vec2 canvas_dims;
uniform vec3 start_pos;
uniform mat4 projview;
out vec2 frag_uv;
void main()
{
    frag_uv = offsets_uv.zw;
   gl_Position =  projview * vec4(start_pos.x, start_pos.y, start_pos.z, 1) + vec4(offsets_uv.x, offsets_uv.y, 0, 0);    
    // gl_Position =   projview * vec4(start_pos.x+offsets_uv.x, start_pos.y + offsets_uv.y,  start_pos.z, 1);
    //gl_Position =   projview * vec4(offsets_uv.x, offsets_uv.y,  0, 1);
}

