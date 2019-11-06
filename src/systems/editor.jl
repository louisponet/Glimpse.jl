@component struct EditorMoveGuides
    es::NTuple{4, Entity} #for now only x,y,z axis and sphere
end
@component struct EditorRotateGuides
    es::NTuple{3, Entity} 
end

@component_with_kw struct Movable
    axis_thickness::Float32 = 0.2f0
    axis_length::Float32    = 5f0
    font_size::Float32 = 0.3f0
end

@component_with_kw struct Rotatable
    ring_radii::Float32 = 5f0
    rotation_speed::Float32 = 0.02f0/200
    font_size::Float32 = 0.3f0
end

struct Editor <: System end

Overseer.requested_components(::Editor) = (Movable, Rotatable, InstancedDefaultVao, EditorMoveGuides, EditorRotateGuides)

function Overseer.update(::Editor, m::AbstractLedger)
    poly_vao           = m[InstancedDefaultVao]
    movable       = m[Movable]
    rotatable     = m[Rotatable]
    spatial       = m[Spatial]
    rotation_comp      = m[Rotation]
    move_guides   = m[EditorMoveGuides]
    rotate_guides = m[EditorRotateGuides]
    text     = m[Text]
    text_vao  = m[TextVao]
    line_vao  = m[LineVao]

    poly       = m[PolygonGeometry] #arrows are here
    selectable = m[Selectable]
    camera     = singleton(m, Camera3D) #this we need to know how much a dragged mouse correspond to a movement in the world
    camera_entity = Entity(m[Camera3D].indices.packed[1])
    eye = spatial[camera_entity].position
    keyboard = singleton(m, Keyboard)
    mouse    = singleton(m, Mouse)
    rotated = false
    moved = false

    set_visibility = b -> begin
        for g in (move_guides, rotate_guides)
            for e in @entities_in(g)
                for guide_entity in g[e].es
                    if guide_entity in poly_vao
                        poly_vao[guide_entity].visible = b
                    end
                    if guide_entity in text_vao
                        text_vao[guide_entity].visible = b
                    end
                    if guide_entity in line_vao
                        line_vao[guide_entity].visible = b
                    end
                end
            end
        end
    end

    if pressed(keyboard) && keyboard.button ∈ CTRL_KEYS
        set_visibility(true)
        #setup move guides 
        for e in @entities_in(movable && spatial && !move_guides)
            mov = movable[e]
            editor_guides  = assemble_axis_arrows(spatial[e].position, axis_length=mov.axis_length, thickness=mov.axis_thickness)
            guide_entities = map(x -> Entity(m, x..., Selectable()), editor_guides)
            move_guides[e] = EditorMoveGuides(guide_entities)
        end

        #setup rotation_comp guides
        for e in @entities_in(rotatable && spatial && !rotate_guides)
            if !in(e, rotation_comp)
                rotation_comp[e] = Rotation(Z_AXIS, 0f0)
            end

            editor_guides  = assemble_orientation_sphere(spatial[e].position, radius=rotatable[e].ring_radii)
            guide_entities = map(x -> Entity(m, x..., Selectable(color_modifier=1.5f0)), editor_guides)
            rotate_guides[e] = EditorRotateGuides(guide_entities)
        end

        #sanitize positions of move_guides
        for e in @entities_in(move_guides)
            guide_entities = move_guides[e].es
            t_spat = spatial[e]
            for g in guide_entities
                spatial[g] = t_spat
            end
            pos = t_spat.position
            text[guide_entities[1]] = Text(str="Position: (x=$(pos[1]), y=$(pos[2]), z=$(pos[3]))", font_size=movable[e].font_size, align=:top, offset=Vec3f0(0, 0, -2f0))
        end

        #sanitize positions and orientiations of rotation_comp guides
        for e in @entities_in(rotate_guides)
            rot = rotation_comp[e]
            guide_entities = rotate_guides[e].es
            for guide in guide_entities
                spatial[guide] = spatial[e]
            end
            ax = direction(rot)
            rotation_comp[guide_entities[1]] = rot #this is the in plane one, so should rotate along the direction of the object
            # rotation_comp[guide_entities[2]] = Rotation(rot.q * rotation(Y_AXIS, X_AXIS))#this is the out of plane one, so should rotate along the perpendicular direction of the object
            rotation_comp[guide_entities[2]] = Rotation(rot.q*rotation(X_AXIS, Z_AXIS))
            rotation_comp[guide_entities[3]] = Rotation(rot.q*rotation(Y_AXIS, Z_AXIS))
             #this is the out of plane one, so should rotate along the perpendicular direction of the object
            text[guide_entities[1]] = Text(str="Orientation: (x=$(ax[1]), y=$(ax[2]), z=$(ax[3]))", font_size=rotatable[e].font_size, align=:top, offset=Vec3f0(0, 0, -2f0))
        end

        #handle moving
        for parent_entity in @entities_in(move_guides)
            for e in move_guides[parent_entity].es[2:end]
                if selectable[e].selected
                    if pressed(mouse)
                        mouse_drag = (mouse.dx * camera.right - mouse.dy * camera.up) * camera.translation_speed / 2
                        guide_direction = direction(rotation_comp[e])
                        move = guide_direction * dot(guide_direction, mouse_drag)

                        t_spat = spatial[parent_entity]
                        spatial[parent_entity] = Spatial(t_spat, position=t_spat.position + move)
                        moved = true
                    end
                end
            end
        end

        #handle rotating
        for parent_entity in @entities_in(rotate_guides)
            rotate_entities = rotate_guides[parent_entity].es
            for e in rotate_entities
                if selectable[e].selected
                    if pressed(mouse)
                        rotation_axis = direction(rotation_comp[e])
                        ray = Ray(mouse, singleton(m, Canvas), camera, eye)
                        plane = Plane(spatial[e].position, rotation_axis)
                        closest_point = intersect(ray, plane)
                        tangent = cross(rotation_axis, closest_point - spatial[e].position)
                        mouse_drag = (mouse.dx * camera.right - mouse.dy * camera.up) * rotatable[parent_entity].rotation_speed
                        
                        guide_rotation = Quaternions.qrotation(rotation_axis, dot(tangent, mouse_drag)) 

                        t_rot = rotation_comp[parent_entity]
                        rotation_comp[parent_entity] = Rotation(guide_rotation*t_rot.q)
                        rotated=true
                    end
                end
            end
        end
    else
        set_visibility(false)
    end
    rotated && push!(singleton(m, UpdatedComponents), Rotation)
    moved && push!(singleton(m, UpdatedComponents), Spatial)
end


