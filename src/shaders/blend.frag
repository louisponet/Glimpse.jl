#version 330 core
in vec2 tex_coord;
out vec4 color;

uniform sampler2D color_texture;
void main(){
    color = texture(color_texture, tex_coord);
    // color *= vec4(0.0,0.0,0.0, 1.0);
    // color.r = 1.0;
}
