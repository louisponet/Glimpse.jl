#version 410
in vec2 tex_coord;
out vec4 color;

uniform sampler2D color_texture;
uniform sampler2D depth_texture;
void main(){
    vec4 depth = texture(depth_texture, tex_coord);
    depth.r -=0.5;
    // Mask out background which is set to 1
    // if(depth.r<1){
        // color = texture(color_texture, tex_coord);
        // color.r = 0.0;
        color.r = depth.r;
    // }
    // else{
    //     discard;
    // }
}
