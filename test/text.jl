using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(background=RGBAf0(1.0,1.0,1.0,1.0);interactive=true);
dio[Gl.TimingData][1].preferred_fps = 1
Entity(dio, Gl.Text(), Gl.Spatial(), Gl.UniformColor(RGBAf0(1.0, 0.0,0.0,1.0)))
