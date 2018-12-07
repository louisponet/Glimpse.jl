#version 410
in vec3 fragcolor;
in vec3 fragnormal;
in vec3 world_pos;
out vec4 out_color;

struct point_light {
    vec3 position;
    float amb_intensity;
    float diff_intensity;
    vec3 color;
};

uniform vec3 campos;
uniform float specpow;
uniform float specint;
uniform float alpha;

uniform point_light plight;
void main () {

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
            specular_factor = pow(specular_factor, specpow);
            specular_color = vec4(plight.color * specint * specular_factor,1.0f);
        }
    }

    // out_color = vec4(plight.color, 1.0f);
    out_color = vec4(fragcolor, alpha) * ( ambient_color+ diffuse_color + specular_color);
}
