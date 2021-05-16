using CImGui.CSyntax
using CImGui.CSyntax.CStatic

#TODO what to do with contexts, do we actually need to save them? Should they all be in the canvas?
@component @with_kw mutable struct GuiInfo
    show_gui::Bool = false
end

@component struct GuiText
    text::String
end

@component @with_kw struct GuiFuncs
    funcs::Vector{Function} = Function[]
end

struct GuiRenderer <: AbstractRenderSystem end

Overseer.requested_components(::GuiRenderer) = (GuiFuncs, GuiText)

Overseer.prepare(::GuiRenderer, dio::Diorama) = isempty(dio[GuiFuncs]) && (dio[Entity(1)] = GuiFuncs();dio[Entity(1)] = GuiInfo())

function Overseer.update(::GuiRenderer, m::AbstractLedger)
    camera = singleton(m, Camera3D)
    gui_info = singleton(m, GuiInfo)
    keyboard = singleton(m, Keyboard)

    if pressed(keyboard) && keyboard.button == GLFW.KEY_G
        gui_info.show_gui = keyboard.modifiers != 1
    end

    if gui_info.show_gui 
        ImGui_ImplOpenGL3_NewFrame()
        ImGui_ImplGlfw_NewFrame()
        Gui.NewFrame()
        # if Gui.Checkbox("Show GUI")
        if !isempty(m[GuiText])
            Gui.Begin("User Text")
            camera.locked = Gui.IsWindowFocused() || camera.locked
            Gui.SetWindowFontScale(2.0f0)
            for e in m[GuiText]
                Gui.Text(e.text)
            end
            Gui.End()
        end

        # Submitted Gui Funcs
        fs = singleton(m, GuiFuncs).funcs
        for (i, f) in enumerate(fs)
            f()
        end
        empty!(fs)
        camera.locked = Gui.IsAnyItemActive() || camera.locked
        Gui.Render()
        ImGui_ImplOpenGL3_RenderDrawData(Gui.GetDrawData())
    end


    # Components Debug
    # Gui.Begin("Components")
 #    Gui.SetWindowFontScale(2.0f0)
    # for c in filter(x -> !isempty(x), renderer.data.components)
    #     if Gui.TreeNode(replace("$(eltype(c))", "Glimpse." => ""))
    #         eids = @valid_entities_in(c)
    #         if length(eids) < 5
    #             for e in eids
    #                 if Gui.TreeNode("$e")
    #                     Gui.Text("$(c[e])")
    #                     Gui.TreePop()
    #                 end
    #             end
    #         end
    #         Gui.TreePop()
    #     end
    # end
    # Gui.End()
    ###
end
