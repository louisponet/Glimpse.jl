#version 330

/* \brief Fragment GLSL shader that demonstrates how perform pass through fragment shader.
 * This file is a part of shader-3dcurve example (https://github.com/vicrucann/shader-3dcurve).
 * \author Victoria Rudakova
 * \date January 2017
 * \copyright MIT license
*/

in VertexData{
    vec2 mTexCoord;
    vec4 mColor;
} VertexIn;

uniform vec3 object_id_color;
layout (location=0) out vec4 fragcolor;
layout (location=1) out vec3 id_color;

void main(void)
{
    fragcolor = VertexIn.mColor;
    id_color = object_id_color;
}
