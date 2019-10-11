using CImGui.CSyntax
using CImGui.CSyntax.CStatic

#TODO what to do with contexts, do we actually need to save them? Should they all be in the canvas?
@component struct GuiText
	text::String
end

@component_with_kw struct GuiFuncs
	funcs::Vector{Function} = Function[]
end

struct GuiRenderer <: AbstractRenderSystem end

requested_components(::GuiRenderer) = (GuiFuncs, GuiText)

ECS.prepare(::GuiRenderer, dio::Diorama) = isempty(dio[GuiFuncs]) && Entity(dio, GuiFuncs())

function update(::GuiRenderer, m::ECS.AbstractManager)
    return 
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    Gui.NewFrame()

	Gui.Begin("User Text")
    Gui.SetWindowFontScale(2.0f0)
    for e in m[GuiText]
        Gui.Text(e.text)
    end
	Gui.End()

	# Submitted Gui Funcs
	fs = m[GuiFuncs][1].funcs
	for f in fs
		f()
	end
	empty!(fs)

	# Components Debug
	# Gui.Begin("Components")
 #    Gui.SetWindowFontScale(2.0f0)
	# for c in filter(x -> !isempty(x), renderer.data.components)
	# 	if Gui.TreeNode(replace("$(eltype(c))", "Glimpse." => ""))
	# 		eids = valid_entities(c)
	# 		if length(eids) < 5
	# 			for e in eids
	# 				if Gui.TreeNode("$e")
	# 					Gui.Text("$(c[e])")
	# 					Gui.TreePop()
	# 				end
	# 			end
	# 		end
	# 		Gui.TreePop()
	# 	end
	# end
	# Gui.End()
	###
    Gui.Render()
    ImGui_ImplOpenGL3_RenderDrawData(Gui.GetDrawData())
end
