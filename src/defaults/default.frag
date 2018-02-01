# version 410

in vec3 outcolor;
out vec4 outColor;

void main()
{
    outColor = vec4(outcolor.xyz, 1.0);
}
