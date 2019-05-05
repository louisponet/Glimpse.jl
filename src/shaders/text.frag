#version 420
in vec2 frag_uv;
uniform sampler2D glyph_texture;
uniform vec4 color;
layout (location = 0) out vec4 out_color;
void main()
{
    out_color = vec4(color.xyz, 1-texture(glyph_texture, frag_uv).r);
    //out_color = vec4(sampled.a,0.0,1.0,1.0);
}
