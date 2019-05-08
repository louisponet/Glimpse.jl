#version 420

layout (location = 0) in vec2 uv;
layout (location = 1) in vec4 space_o_wh;
layout (location = 2) in vec4 uv_offset_width;
uniform vec3 start_pos;
uniform mat4 projview;
out vec2 frag_uv;
void main()
{
   frag_uv = uv_offset_width.xy + vec2(uv.x * uv_offset_width.z , uv.y * uv_offset_width.w);
   gl_Position = vec4(space_o_wh.x + uv.x*space_o_wh.z, space_o_wh.y + abs(uv.y-1)*space_o_wh.w, 0, 0)+ projview * vec4(start_pos, 1);    
    //gl_Position =   projview * vec4(offsets_uv.x, offsets_uv.y,  0, 1);
}

