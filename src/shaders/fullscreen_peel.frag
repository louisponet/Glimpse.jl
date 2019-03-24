#version 420
in  vec2 tex_coord;
out vec4 color;

layout(binding=0) uniform sampler2D color_texture;
layout(binding=1) uniform sampler2D depth_texture;
layout(binding=2) uniform sampler2D prev_depth;
uniform bool first_pass;

void main(){
    // vec2 tex_coord = vec2(float(gl_FragCoord.x) / canvas_width, float(gl_FragCoord.y) / canvas_height);
    float depth = texture(depth_texture, tex_coord).r;

    if (!first_pass){
		float max_depth = texture(prev_depth, tex_coord).r;
		if (depth <= max_depth){
			discard;
		}
		else {
			color        = vec4(texture(color_texture, tex_coord).rgb, 1);
			gl_FragDepth = texture(depth_texture, tex_coord).r;
		}	
	}
	else {
		color        = vec4(texture(color_texture, tex_coord).rgb, 0);
		gl_FragDepth = texture(depth_texture, tex_coord).r;
	}
}
