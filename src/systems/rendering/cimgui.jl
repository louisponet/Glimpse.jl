using CImGui.CSyntax
using CImGui.CSyntax.CStatic

#TODO what to do with contexts, do we actually need to save them? Should they all be in the canvas?
struct GuiText <: ComponentData
	text::String
end

struct GuiRenderer <: AbstractRenderSystem
	data       ::SystemData

	function GuiRenderer(dio::Diorama)
		w = nativewindow(singleton(dio, Canvas))
		ctx = convert(UInt, CImGui.GetCurrentContext())
		if ctx == 0
			ctx = convert(UInt, CImGui.CreateContext())
		else
			CImGui.DestroyContext(CImGui.GetCurrentContext())
			ctx = convert(UInt, CImGui.CreateContext())
		end
		ImGui_ImplGlfw_InitForOpenGL(w, true)
		ImGui_ImplOpenGL3_Init(420)
		return new(SystemData(dio, (GuiText,), ()))
	end
end

function update_indices!(sys::GuiRenderer)
	sys.data.indices = [valid_entities(sys, GuiText)]
end

function update(renderer::GuiRenderer)
    ImGui_ImplOpenGL3_NewFrame()
    ImGui_ImplGlfw_NewFrame()
    CImGui.NewFrame()
	ci_text = component(renderer, GuiText)
    # CImGui.Begin("Another Window")  # pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
    for e in indices(renderer)[1]
        CImGui.Text(ci_text[e].text)
    end
    # CImGui.End()
    CImGui.Render()
    ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())
end



