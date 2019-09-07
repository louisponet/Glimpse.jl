#%%
using Glimpse
const Gl = Glimpse
#%%
dio = Gl.Diorama(interactive=true);

Gl.add_entity!(dio, separate=[Gl.GuiText("test")])
Gl.add_entity!(dio, separate=[Gl.GuiText("test1")])

#%%
