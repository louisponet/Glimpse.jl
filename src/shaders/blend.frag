#version 420
in vec2 tex_coord;

layout (location=0) out vec4 color;
layout (location=1) out vec3 id_color;

layout(binding=0) uniform sampler2D color_texture;
layout(binding=1) uniform sampler2D color_id_texture;

void main(){
    color = texture(color_texture, tex_coord);
    id_color = texture(color_id_texture, tex_coord).rgb;
    // color *= vec4(0.0,0.0,0.0, 1.0);
    // color.r = 1.0;
}
