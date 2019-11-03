@component struct EditorGuides
    es::NTuple{4, Entity} #for now only x,y,z axis and sphere
end

@component struct Moveable end

struct Editor <: System end

Overseer.requested_components(::Editor) = (Moveable, InstancedDefaultVao, EditorGuides)

function Overseer.update(::Editor, m::AbstractLedger)
    vao      = m[InstancedDefaultVao]
    moveable = m[Moveable]
    spatial  = m[Spatial]
    guides   = m[EditorGuides]
    text     = m[Text]
    textvao = m[TextVao]

    poly       = m[PolygonGeometry] #arrows are here
    selectable = m[Selectable]
    camera     = singleton(m, Camera3D) #this we need to know how much a dragged mouse correspond to a movement in the world 

    for e in @entities_in(moveable && spatial && !guides)
        editor_guides  = assemble_axis_arrows(spatial[e].position)
        guide_entities = map(x -> Entity(m, x..., Selectable()), editor_guides)
        guides[e] = EditorGuides(guide_entities)
        pos = spatial[e].position
        text[guide_entities[1]] = Text(str="(x=$(pos[1]), y=$(pos[2]), z=$(pos[3]))", font_size=0.3, align=:top, offset=Vec3f0(0, 0, -2f0))
    end


    keyboard = singleton(m, Keyboard)
    mouse    = singleton(m, Mouse)
    for parent_entity in @entities_in(guides)
        for e in guides[parent_entity].es
            if e ∈ vao
                if pressed(keyboard) && keyboard.button ∈ CTRL_KEYS
                    vao[e].visible = true
                    #TODO this is rather hacky, I'd rather have every mesh be upright with a separate orientation component
                    if selectable[e].selected
                        if pressed(mouse)
                            mouse_drag = (mouse.dx * camera.right - mouse.dy * camera.up) * camera.translation_speed / 2
                            guide_direction = direction(poly[e].geometry)
                            move = guide_direction * dot(guide_direction, mouse_drag)

                            for guide_to_be_moved in guides[parent_entity].es
                                t_spat = spatial[guide_to_be_moved]
                                spatial[guide_to_be_moved] = Spatial(t_spat, position=t_spat.position+move)
                            end
                            t_spat = spatial[parent_entity]
                            spatial[parent_entity] = Spatial(t_spat, position=t_spat.position+move)
                        end
                    end
                else
                    vao[e].visible = false
                end
            end

            if e ∈ textvao
                if pressed(keyboard) && keyboard.button ∈ CTRL_KEYS
                    pos = spatial[e].position
                    text[e] = Text(text[e], str="(x=$(pos[1]), y=$(pos[2]), z=$(pos[3]))", font_size=0.3, align=:top, offset=Vec3f0(0, 0, -2f0))
                    textvao[e].visible = true
                else
                    textvao[e].visible = false
                end
            end
        end
    end
end
