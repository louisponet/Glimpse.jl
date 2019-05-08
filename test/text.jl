using Glimpse
const Gl = Glimpse
dio = Diorama(background=RGBAf0(1.0,1.0,1.0,1.0));
Gl.new_entity!(dio, separate=[Gl.Text(), Gl.Spatial(), Gl.UniformColor(RGBAf0(1.0, 0.0,0.0,1.0))])
Gl.update_system_indices!(dio)
dio.loop = Gl.renderloop(dio)
Gl.close(dio)
