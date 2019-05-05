#version 420

layout (location = 0) in vec4 offsets_uv;
uniform vec2 canvas_dims;
uniform vec2 start_pos;
out vec2 frag_uv;
void main()
{
    frag_uv = offsets_uv.zw;
    gl_Position =  vec4(start_pos.x, start_pos.y, 0, 1) + mat4( vec4(2.0 / canvas_dims[0], 0, 0, 0),
                         vec4(0, 2.0 / canvas_dims[1], 0, 0),
                         vec4(0, 0, -1, 0),
                         vec4(-1, -1, 0, 1)) * vec4(offsets_uv.x, offsets_uv.y, 0, 1);    
    //gl_Position =   projview * vec4(offsets_uv.x + canvas_dims.x, offsets_uv.y + canvas_dims.y,  0, 1);
    //gl_Position =   projview * vec4(offsets_uv.x, offsets_uv.y,  0, 1);
}

