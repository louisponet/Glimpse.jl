import GLAbstraction: start, Pipeline

function start(pipe::Pipeline{:default})
    glEnable(GL_DEPTH_TEST)
    glEnable(GL_CULL_FACE)
    glDepthFunc(GL_LESS)
end
