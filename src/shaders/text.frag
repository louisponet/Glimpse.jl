#version 420
in vec2 frag_uv;
uniform sampler2D glyph_texture;
uniform vec4 color;
layout (location = 0) out vec4 out_color;
void main()
{
	float sampled = 1-texture(glyph_texture, frag_uv).r;
	if (sampled < 0.1)
		discard;

    out_color = vec4(color.xyz, sampled);
    // out_color = vec4(1.0, 0.0,0.0, 1.0);
}
