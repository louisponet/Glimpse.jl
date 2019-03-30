#version 420

in vec2 frag_uv;
in vec4 frag_color;
uniform sampler2D glyph_texture;
layout (location = 0) out vec4 out_color;
void main()
{
	float c = texture(glyph_texture, frag_uv.st).r;
    out_color = vec4((1-c)*frag_color.x, (1-c)*frag_color.y, 0.0, 0.0);
    // out_color = vec4(1.0,0.0,0.0,1.0);
}

