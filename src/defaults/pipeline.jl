import GLAbstraction: start, Pipeline

function start(pipe::Pipeline{:default})

    clear!(current_context())
    glEnable(GL_DEPTH_TEST)

    glDepthFunc(GL_LEQUAL)


    glDisable(GL_CULL_FACE)
end
