#version 420
in vec2 tex_coord;
layout (location = 0) out vec4 color;
layout (location = 1) out vec3 id_color;

layout(binding=0) uniform sampler2D color_texture;
layout(binding=1) uniform sampler2D color_id_texture;


void main(){
    color = vec4(texture(color_texture, tex_coord).rgb, 1.0);
    id_color = texture(color_id_texture, tex_coord).rgb;
}

