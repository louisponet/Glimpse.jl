#version 420
in vec2 tex_coord;
out vec4 color;

layout(binding=0) uniform sampler2D color_texture;
void main(){
    color = vec4(texture(color_texture, tex_coord).rgb, 1.0);
}

