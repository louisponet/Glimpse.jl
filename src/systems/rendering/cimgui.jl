using CImGui.CSyntax
using CImGui.CSyntax.CStatic

#TODO what to do with contexts, do we actually need to save them? Should they all be in the canvas?
struct GuiText <: ComponentData
	text::String
end

# struct GuiFuncs <: Singleton
# 	funcs::Vector{Function}
# end
# GuiFuncs() = GuiFuncs(Function[]) 

# struct GuiRenderer <: AbstractRenderSystem
# 	data       ::SystemData

# 	GuiRenderer(dio::Diorama) = new(SystemData(dio, (ComponentData, ), (Singleton, )))
# end

# function update_indices!(sys::GuiRenderer)
# 	sys.data.indices = [valid_entities(sys, GuiText)]
# end


# function update(renderer::GuiRenderer)
#     ImGui_ImplOpenGL3_NewFrame()
#     ImGui_ImplGlfw_NewFrame()
#     Gui.NewFrame()
# 	ci_text = component(renderer, GuiText)

# 	Gui.Begin("User Text")
#     Gui.SetWindowFontScale(2.0f0)
#     for e in indices(renderer)[1]
#         Gui.Text(ci_text[e].text)
#     end
# 	Gui.End()

# 	# Submitted Gui Funcs
# 	fs = singleton(renderer, GuiFuncs).funcs
# 	for f in fs
# 		f()
# 	end
# 	empty!(fs)

# 	# Components Debug
# 	Gui.Begin("Components")
#     Gui.SetWindowFontScale(2.0f0)
# 	for c in filter(x -> !isempty(x), renderer.data.components)
# 		if Gui.TreeNode(replace("$(eltype(c))", "Glimpse." => ""))
# 			eids = valid_entities(c)
# 			if length(eids) < 5
# 				for e in eids
# 					if Gui.TreeNode("$e")
# 						Gui.Text("$(c[e])")
# 						Gui.TreePop()
# 					end
# 				end
# 			end
# 			Gui.TreePop()
# 		end
# 	end
# 	Gui.End()
# 	###
#     Gui.Render()
#     ImGui_ImplOpenGL3_RenderDrawData(Gui.GetDrawData())
# end
