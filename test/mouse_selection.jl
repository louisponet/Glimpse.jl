#%%
using Revise
using Glimpse
const Gl = Glimpse
#%%

dio = Diorama(background=RGBAf0(1.0));
Gl.renderloop(dio)



#%%
Gl.GLFW.Terminate()
Gl.GLFW.Init()
#%%
