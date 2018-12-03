function start(pipe::Pipeline{:default})

    clear!(current_context())
    glEnable(GL_DEPTH_TEST)

    glDepthFunc(GL_LEQUAL)


    glEnable(GL_CULL_FACE)
    glCullFace(GL_BACK)
end
