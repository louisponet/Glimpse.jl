#version 420

in vec2 frag_uv;
in vec4 frag_color;
uniform sampler2D glyph_texture;
layout (location = 0) out vec4 out_color;
void main()
{
	vec4 sampled = vec4(1.0, 1.0, 1.0, 1-texture(glyph_texture, frag_uv).r);
    out_color = vec4(frag_color.xyz, 1.0) * sampled;
    // out_color = vec4(1.0,0.0,0.0,1.0);
}

