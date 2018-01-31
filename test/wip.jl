using GLider
testvista = Vista(interactive=true)
using GeometryTypes
using ColorTypes
testrenderable = Renderable{3}(1,:test, Dict(:vertices => Point{2,Float32}[(-0.5, -0.5),
                                                                           ( 0.5, -0.5),
                                                                           ( 0.0,  0.5)],
                                             :color    => [RGB(0.2f0,0.9f0,0.5f0),RGB(0.9f0,0.2f0,0.5f0),RGB(0.5f0,0.2f0,0.9f0)]))
testrenderable2 = Renderable{3}(1,:test, Dict(:vertices => Point{2,Float32}[(0.5, 0.5),
                                                                           (-0.5, 0.5),
                                                                           ( 0.0,  -0.5)],
                                             :color    => [RGB(0.2f0,0.9f0,0.5f0),RGB(0.9f0,0.2f0,0.5f0),RGB(0.5f0,0.2f0,0.9f0)]))
                                             
add!(testvista, testrenderable)
add!(testvista, testrenderable2)

