#version 410
in vec4 fragcolor;
in vec3 fragnormal;
in vec3 world_pos;
in vec3 id_color;

in vec2 fragmaterial;

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

uniform point_light plight;
void main () {
	float specPow = fragmaterial[0];
	float specInt = fragmaterial[1];

    vec4 ambient_color  = vec4(plight.color * plight.amb_intensity, 1.0f);
    vec3 light_position = normalize(plight.position - world_pos);
    vec3 normal         = normalize(fragnormal);

    float diffuse_factor = dot(normal, light_position);


    vec4 diffuse_color = vec4(0.0f,0.0f,0.0f,0.0f);
    vec4 specular_color = vec4(0.0f,0.0f,0.0f,0.0f);

    if (diffuse_factor > 0.0f){
        diffuse_color = vec4(plight.color, 1.0f) * plight.diff_intensity * diffuse_factor;
        vec3 vertex_to_eye = normalize(campos - world_pos);
        vec3 light_reflect = normalize(reflect( -plight.position, normal));
        float specular_factor = dot(vertex_to_eye, light_reflect);
        if(specular_factor > 0) {
            specular_factor = pow(specular_factor, specPow);
            specular_color = vec4(plight.color  * specInt * plight.specular_intensity* specular_factor,1.0f);
        }
    }

    // out_color = vec4(plight.color, 1.0f);
    // out_color = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    out_color = fragcolor * ( ambient_color+ diffuse_color + specular_color);
    out_id_color = id_color;
}
