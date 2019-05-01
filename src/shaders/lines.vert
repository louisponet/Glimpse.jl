
#version 330

/* \brief Vertex GLSL shader that demonstrates how to draw basic thick and smooth lines in 3D.
 * This file is a part of shader-3dcurve example (https://github.com/vicrucann/shader-3dcurve).
 *
 * \author Victoria Rudakova
 * \date January 2017
 * \copyright MIT license
*/


layout(location = 0) in vec3 vertices;
layout(location = 1) in vec4 color;

uniform mat4 projview, modelmat;
out VertexData{
    vec4 mColor;
} VertexOut;

void main(void)
{
    VertexOut.mColor = color;
    gl_Position = projview*modelmat * vec4(vertices, 1.0);
}
