#%%
using Revise
using Glimpse
const Gl = Glimpse
#%%
dio = Gl.Diorama();

Gl.add_entity!(dio, separate=[Gl.GuiText("test")])
Gl.add_entity!(dio, separate=[Gl.GuiText("test1")])
# Gl.add_entity!(dio, separate=[Gl.GuiText("test2")])
Gl.update_system_indices!(dio)
Gl.renderloop(dio)
Gl.close(dio)

#%%
Gl.glfw_destroy_current_context()

#%%
using CImGui

