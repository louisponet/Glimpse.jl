#version 330 core
in vec2 tex_coord;
out vec4 color;

uniform sampler2D color_texture;
void main(){
    color = vec4(texture(color_texture, tex_coord).rgb, 1);
}
