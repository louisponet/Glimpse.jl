#version 420
in vec3 position;
in vec2 uv;
out vec2 tex_coord;
void main(){
    gl_Position = vec4(position,1.);
    tex_coord = uv;
}
