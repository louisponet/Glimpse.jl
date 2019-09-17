#%%
using Glimpse
const Gl = Glimpse
#%%
dio = Gl.Diorama(interactive=true);

Entity(dio, Gl.GuiText("test"))
Entity(dio, Gl.GuiText("test1"))

#%%
