#version 420
// in vec4 fragcolor;
in vec3 fragnormal;
in vec3 world_pos;
in vec2 fragmaterial;
in vec3 id_color;
in vec4 fragcolor;


layout (location = 0) out vec4 out_color;
layout (location = 1) out vec3 out_id_color;

struct point_light {
    vec3 position;
    float amb_intensity;
    float diff_intensity;
    float specular_intensity;
    vec3 color;
};

uniform vec3 campos;

// peeling uniforms
uniform float canvas_width;
uniform float canvas_height;
uniform bool first_pass;
uniform point_light plight;
layout(binding=0) uniform sampler2D depth_texture;

void main () {
	if (fragcolor[3] == 0) {
		discard;
	}
	float specPow = fragmaterial.x;
	float specInt = fragmaterial.y;
    vec3 ambient_color  = plight.color * plight.amb_intensity;
    vec3 light_position = normalize(plight.position - world_pos);
    vec3 normal         = normalize(fragnormal);

    float diffuse_factor = dot(normal, light_position);


    vec3 diffuse_color = vec3(0.0f,0.0f,0.0f);
    vec3 specular_color = vec3(0.0f,0.0f,0.0f);

    if (diffuse_factor > 0.0f){
        diffuse_color = plight.color * plight.diff_intensity * diffuse_factor;
        vec3 vertex_to_eye = normalize(campos - world_pos);
        vec3 light_reflect = normalize(reflect( -plight.position, normal));
        float specular_factor = dot(vertex_to_eye, light_reflect);
        if(specular_factor > 0) {
            specular_factor = pow(specular_factor, specPow);
            specular_color = plight.color  * specInt * plight.specular_intensity* specular_factor;
        }
    }
    vec3 relcolor = ambient_color + diffuse_color + specular_color;// specular_color;
    if(!first_pass){
        vec2 tex_coord = vec2(float(gl_FragCoord.x) / canvas_width, float(gl_FragCoord.y) / canvas_height);
        float max_depth = texture(depth_texture, tex_coord).r;
        if (gl_FragCoord.z <= max_depth){
            discard;
            // out_color = vec4(0.0, 0.0, max_depth, 0.1);
        }
        else{
            out_color = vec4(relcolor*fragcolor.rgb * fragcolor.a, fragcolor.a);
        }
    }
    else{
        out_color = vec4(relcolor* fragcolor.rgb * fragcolor.a, 1.0 - fragcolor.a);
		out_id_color = id_color;
    }
}
