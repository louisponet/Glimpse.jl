using Glimpse
const Gl = Glimpse
dio = Gl.Diorama(background=RGBAf0(1.0,1.0,1.0,1.0));
Gl.add_entity!(dio, separate=[Gl.Text(), Gl.Spatial(), Gl.UniformColor(RGBAf0(1.0, 0.0,0.0,1.0))])
Gl.update_system_indices!(dio)
for sys in Gl.engaged_systems(dio)
	Gl.update(sys)
end
Gl.close(dio)
