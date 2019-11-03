#version 420
in vec2 tex_coord;

layout (location=0) out vec4 color;

layout(binding=0) uniform sampler2D color_texture;

void main(){
    color = texture(color_texture, tex_coord);
    // color *= vec4(0.0,0.0,0.0, 1.0);
    // color.r = 1.0;
}
