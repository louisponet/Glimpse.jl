using GLider
using GeometryTypes
using ColorTypes
testrenderable = Renderable{3}(1,:test, Dict(:vertices => Point{2,Float32}[(-0.5, -0.5),
                                                                           ( 0.5, -0.5),
                                                                           ( 0.0,  0.5)],
                                             :color    => [RGB(0.2f0,0.9f0,0.5f0),RGB(0.9f0,0.2f0,0.5f0),RGB(0.5f0,0.2f0,0.9f0)]))
                                            #  :faces => Face{3,UInt32}[(0,1,2)]))
testscene = Scene(:test, [testrenderable])

vertex_shader = vert"""
#version 410

layout(location = 0) in vec2 position;
layout(location = 1) in vec3 color;

out vec3 outcolor;

void main()
{
    outcolor = color;
    gl_Position = vec4(position, 0.0, 1.0);
}
"""

# The fragment shader
fragment_shader = frag"""
# version 410

in vec3 outcolor;
out vec4 outColor;

void main()
{
    outColor = vec4(outcolor.xyz, 1.0);
}
"""

screen = Screen()
camera = Camera{perspective}(Vec3f0(0), Vec3f0(1), Vec3f0(0.0f0,0.0f0,1.0f0),Vec3f0(-1.0f0,0.0f0,0.0f0),screen.area)
renderpass = RenderPass(:test, [vertex_shader, fragment_shader])
pipeline   = Pipeline(:test, [renderpass], screen.canvas) 

#I am still on the fence about using Base.clear!
#I think everything should be in the namespace of GLAbstraction, 
#so it's clear that you have to overload GLAbstraction.clear!
function (rp::RenderPass{:test})(scene::Scene)
    clear!(current_context())
    for renderable in scene.renderables
        bind(renderable)
        draw(renderable)
    end
    unbind(scene.renderables[1])
end

try
while isopen(screen)
    render(pipeline, testscene) 
    swapbuffers(screen)
    waitevents(screen)
end
finally
    destroy!(screen)
    free!(pipeline)
    free!(testscene)
end


