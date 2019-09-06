using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(background=RGBAf0(1.0,1.0,1.0,1.0));
Gl.singleton(dio, Gl.TimingData).preferred_fps = 1
Gl.add_entity!(dio, separate=[Gl.Text(), Gl.Spatial(), Gl.UniformColor(RGBAf0(1.0, 0.0,0.0,1.0))])
