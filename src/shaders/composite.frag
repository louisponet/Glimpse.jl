#version 330 core
in vec2 tex_coord;
out vec4 color;

uniform sampler2D color_texture;
uniform sampler2D depth_texture;
void main(){
    vec4 depth = texture(depth_texture, tex_coord);
    if(depth.r<1){
        color = texture(color_texture, tex_coord);
    }
    else{
        discard;
    }
}
