#version 420

layout (location=1) in vec4 color;
layout (location=2) in vec4 offset_width;
layout (location=3) in vec4 uv_texture_bbox;
layout (location=4) in vec4 rotation; //quaternion


//{{color_map_type}}    color_map;
//{{intensity_type}}    intensity;
//{{color_norm_type}}   color_norm;
//{{uv_offset_width_type}} uv_offset_width;
//{{uv_x_type}} uv_width;
//{{position_x_type}} position_x;
//{{position_y_type}} position_y;
//{{position_z_type}} position_z;
//{{scale_x_type}} scale_x;
//{{scale_y_type}} scale_y;
//{{scale_z_type}} scale_z;
//{{stroke_color_type}} stroke_color;
//{{glow_color_type}}   glow_color;


out vec4  g_offset_width;
out vec4  g_uv_texture_bbox;
out vec4  g_rotation;
out vec4  g_color;
//out vec4  g_stroke_color;
//out vec4  g_glow_color;

void main(){
    g_offset_width = offset_width;
    g_color           = color;
    g_rotation        = rotation;
    g_uv_texture_bbox = uv_texture_bbox;
  //  g_stroke_color    = stroke_color;
  //  g_glow_color      = glow_color;

}


