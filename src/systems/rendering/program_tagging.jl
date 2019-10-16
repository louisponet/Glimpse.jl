struct ProgramTagger <: System end

function update(::ProgramTagger, m::AbstractManager)
    line_prog_tag = m[ProgramTag{LineProgram}]

    default_prog_tag = m[ProgramTag{DefaultProgram}]
    instanced_default_prog_tag = m[ProgramTag{InstancedDefaultProgram}]
    peeling_prog_tag = m[ProgramTag{PeelingProgram}]
    instanced_peeling_prog_tag = m[ProgramTag{InstancedPeelingProgram}]

    ucolor = m[UniformColor]
    for e in entities(m[Line], m[VectorGeometry], ucolor, exclude=(line_prog_tag,))
        line_prog_tag[e] = ProgramTag{LineProgram}()
    end

    for geom in components(m, Geometry)
        #uniform colored meshes/geometry always get instanced
        for e in entities(m[Spatial], geom, ucolor, exclude=(instanced_default_prog_tag, instanced_peeling_prog_tag))
            c = ucolor[e]
            if c.color.alpha < 1
                instanced_peeling_prog_tag[e] = ProgramTag{InstancedPeelingProgram}()
            else
                instanced_default_prog_tag[e] = ProgramTag{InstancedDefaultProgram}()
            end
        end
        # meshes/geometry with other kind of colors always get rendered separately
        for color in components(m, Color)
            eltype(color) == UniformColor && continue
            for e in entities(m[Spatial], geom, color, exclude=(default_prog_tag, peeling_prog_tag))
                c = color[e].color
                if any(x -> x.alpha < 1, c)
                    peeling_prog_tag[e] = ProgramTag{PeelingProgram}()
                else
                    default_prog_tag[e] = ProgramTag{DefaultProgram}()
                end
            end
        end
    end
end
