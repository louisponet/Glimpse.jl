struct Uploader <: System end

function Overseer.requested_components(::Uploader)
    return (Mesh, BufferColor, DefaultVao, DefaultProgram, LineVao, LineProgram,
            PeelingProgram, PeelingVao, LineGeometry, Alpha, Visible)
end

shaders(::Type{DefaultProgram}) = default_shaders()
shaders(::Type{PeelingProgram}) = peeling_shaders()
shaders(::Type{InstancedDefaultProgram}) = instanced_default_shaders()
shaders(::Type{InstancedPeelingProgram}) = instanced_peeling_shaders()
shaders(::Type{PeelingCompositingProgram}) = peeling_compositing_shaders()
shaders(::Type{CompositingProgram}) = compositing_shaders()
shaders(::Type{BlendProgram}) = blending_shaders()
shaders(::Type{FXAAProgram}) = fxaa_shaders()
#TODO there is some preparation doubling here!

#TODO cleanup: really not the place to do this
function Overseer.prepare(::Uploader, dio::Diorama)
    for prog in components(dio, RenderProgram)
        if isempty(prog)
            ProgType = eltype(prog)
            dio[Entity(1)] = ProgType(Program(shaders(ProgType)))
        end
    end
end

function Overseer.update(::Uploader, m::AbstractLedger)
    mesh, bcolor, ucolor = m[Mesh], m[BufferColor], m[UniformColor]
    default_vao = m[DefaultVao]
    peeling_vao = m[PeelingVao]
    line_vao = m[LineVao]
    peeling_prog = singleton(m, PeelingProgram)
    default_prog = singleton(m, DefaultProgram)
    line_prog = singleton(m, LineProgram)
    uc = singleton(m, UpdatedComponents)
    alpha = m[Alpha]

    #Buffer color entities are always not instanced
    for e in @entities_in(mesh && bcolor && !default_vao && !peeling_vao)
        gen_vao = prog -> begin
            buffers = [generate_buffers(prog, e.mesh);
                       generate_buffers(prog, GEOMETRY_DIVISOR; color = e.color)]
            return VertexArray(buffers, map(x -> x .- GLint(1), faces(e.mesh)))
        end

        if e in alpha && alpha[e].α < 1
            peeling_vao[e] = PeelingVao(gen_vao(peeling_prog))
        else
            default_vao[e] = DefaultVao(gen_vao(default_prog))
        end
    end
    line_geom = m[LineGeometry]
    #Line Entities
    for e in @entities_in(line_geom)
        vert_loc = attribute_location(line_prog.program, :vertices)
        color_loc = attribute_location(line_prog.program, :color)

        if e in ucolor
            color_vec = fill(ucolor[e].color, length(e.points))
        elseif e in bcolor
            color_vec = bcolor[e].color
        else
            continue
        end

        if !(e in line_vao)
            color_attach = BufferAttachmentInfo(:color, color_loc, Buffer(color_vec),
                                                GEOMETRY_DIVISOR)
            points_attach = BufferAttachmentInfo(:vertices, vert_loc, Buffer(e.points),
                                                 GEOMETRY_DIVISOR)
            line_vao[e] = LineVao(VertexArray([points_attach, color_attach],
                                              GL_LINE_STRIP_ADJACENCY))
        else
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :vertices).buffer,
                             e.points)
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :color).buffer,
                             color_vec)
        end
    end

    # Add rendered entities to the Visible component if it's not existing yet.
    # I.e. if not set to be invisible they will be visible
    vis = m[Visible]
    for comp in (default_vao, peeling_vao, line_vao)
        for e in @entities_in(comp && !vis)
            vis[e] = Visible()
        end
    end
end

struct InstancedUploader <: System end

function Overseer.update(::InstancedUploader, m::AbstractLedger)
    default_prog = m[InstancedDefaultProgram][1].program
    peeling_prog = m[InstancedPeelingProgram][1].program
    default_vao  = m[InstancedDefaultVao]
    peeling_vao  = m[InstancedPeelingVao]
    idc          = m[Selectable]
    mesh         = m[Mesh]
    if isempty(mesh)
        return
    end
    ucolor = m[UniformColor]
    modelmat = m[ModelMat]
    material = m[Material]
    alpha = m[Alpha]
    vis = m[Visible]

    default_entities = @entities_in(mesh && ucolor && modelmat && material && !alpha)
    peeling_entities = @entities_in(mesh && ucolor && modelmat && material && alpha)
    n_default = length(default_entities)
    n_peeling = length(peeling_entities)

    ndef = isempty(default_vao) ? 0 : sum(x -> x.vertexarray.ninst, default_vao)
    npeel = isempty(peeling_vao) ? 0 : sum(x -> x.vertexarray.ninst, peeling_vao)

    if n_default == ndef && n_peeling == npeel
        return
    end

    max_entities = maximum(mesh.group_size)
    modelmats    = Vector{ModelMat}(undef, max_entities)
    materials    = Vector{Material}(undef, max_entities)
    ids          = Vector{Entity}(undef, max_entities)
    colors       = Vector{UniformColor}(undef, max_entities)
    idcolors     = Vector{RGBf0}(undef, max_entities)
    alphas       = Vector{Alpha}(undef, max_entities)

    for (i, m) in enumerate(mesh)
        default_it = @entities_in(entity_group(mesh, i) &&
                                  ucolor &&
                                  modelmat &&
                                  material &&
                                  !alpha)
        peeling_it = @entities_in(entity_group(mesh, i) &&
                                  ucolor &&
                                  modelmat &&
                                  material &&
                                  alpha)
        for (it, vao, prog, vao_T) in
            zip((default_it, peeling_it), (default_vao, peeling_vao),
                (default_prog, peeling_prog), (InstancedDefaultVao, InstancedPeelingVao))
            tot = length(it)
            if i <= length(vao.group_size) && tot == vao.data[i].vertexarray.ninst
                # Nothing to be done for this meshgroup
                continue
            end

            for (ie, e) in enumerate(it)
                modelmats[ie] = e[ModelMat]
                materials[ie] = e[Material]
                ids[ie] = e.e
                colors[ie] = e[UniformColor]
                if e in idc
                    idcolors[ie] = idc[e].color
                else
                    idcolors[ie] = RGBf0(1, 1, 1)
                end
                if !(e in vis)
                    vis[e] = Visible()
                end
                if e in alpha
                    alphas[ie] = vis[e].visible ? alpha[e] : Alpha(0)
                else
                    alphas[ie] = vis[e].visible ? Alpha(1) : Alpha(0)
                end
            end

            if (tot > 0 && length(vao.group_size) < i)
                # Mesh needs to be uploaded, only time when a vao gets created
                buffers = [generate_buffers(prog, m.mesh);
                           generate_buffers(prog, GLA.UNIFORM_DIVISOR;
                                            color = view(colors, 1:tot),
                                            modelmat = view(modelmats, 1:tot),
                                            material = view(materials, 1:tot),
                                            object_id_color = view(idcolors, 1:tot),
                                            alpha = view(alphas, 1:tot))]
                vao[ids[1]] = vao_T(VertexArray(buffers,
                                                map(x -> x .- GLint(1), m.mesh.faces), tot))
                for e in ids[2:tot]
                    vao[e] = ids[1]
                end

            elseif i <= length(vao.group_size) && tot != vao.data[i].vertexarray.ninst
                # buffers need to be reuploaded because entities were added
                upload_buffer!(vao.data[i], view(colors, 1:tot))
                upload_buffer!(vao.data[i], view(modelmats, 1:tot))
                upload_buffer!(vao.data[i], view(materials, 1:tot))
                upload_buffer!(vao.data[i], view(idcolors, 1:tot), :object_id_color)
                upload_buffer!(vao.data[i], view(alphas, 1:tot))
                vao.data[i].vertexarray.ninst = tot
                to_remove = Entity[]
                for e in entity_group(vao, i)
                    if !in(e, it)
                        push!(to_remove, e)
                    end
                end
                delete!(vao, to_remove)
                p = parent(vao, i)
                for e in ids
                    if e == p
                        continue
                    end
                    vao[e] = p
                end
            end
        end
    end
end

struct UniformUploader <: System end

function Overseer.requested_components(::UniformUploader)
    return (InstancedDefaultVao, InstancedPeelingVao, ModelMat, Selectable, UniformColor,
            UpdatedComponents)
end

# function find_contiguous_bounds(indices)
#     ranges = UnitRange[]
#     i = 1
#     cur_start = indices[1]
#     while i <= length(indices) - 1
#         id = indices[i]
#         id_1 = indices[i + 1]
#         if id_1 - id != 1
#             push!(ranges, cur_start:id)
#             cur_start = id_1
#         end
#         i += 1
#     end
#     push!(ranges, cur_start:indices[end])
#     return ranges
# end

"Uploads buffer using glBufferSubData."
function upload_buffer!(vao, vec::AbstractVector{T}, sym = shader_symbol(T)) where {T}
    binfo = GLA.bufferinfo(vao.vertexarray, sym)
    if binfo !== nothing
        datsize = sizeof(T)
        b = binfo.buffer
        GLA.bind(b)
        n = length(vec)
        s = n * datsize
        if n <= length(b)
            glBufferSubData(b.buffertype, 0, s, pointer(vec, 1))
        else
            glBufferData(b.buffertype, s, pointer(vec, 1), b.usage)
        end
        b.len = n
        GLA.unbind(binfo.buffer)
    end
end

function upload_to_vao!(f::Function, vao_comp, comp,
                        buffer = Vector{eltype(comp)}(undef, maximum(vao_comp.group_size)))
    for (i, v) in enumerate(vao_comp)
        for (ie, e) in enumerate(entity_group(vao_comp, i))
            buffer[ie] = f(comp, e)
        end
        upload_buffer!(v, view(buffer, 1:vao_comp.group_size[i]))
    end
end
function upload_to_vao!(vao_comp::Overseer.AbstractComponent, args...)
    return upload_to_vao!((c, e) -> (@inbounds c[e]), vao_comp, args...)
end

function Overseer.update(::UniformUploader, m::AbstractLedger)
    uc = m[UpdatedComponents][1]
    vis = m[Visible]
    alpha = m[Alpha]
    peel = m[InstancedPeelingVao]
    default = m[InstancedDefaultVao]
    maxsize = max(isempty(peel) ? 0 : maximum(peel.group_size),
                  isempty(default) ? 0 : maximum(default.group_size))
    if maxsize == 0
        return
    end

    # always reupload visible
    push!(uc.components, Alpha)
    for c in filter(x -> shader_symbol(x) != :none, uc.components)
        comp = m[c]
        vec  = Vector{eltype(comp)}(undef, maxsize)
        for vao in (default, peel)
            if isempty(vao)
                continue
            end
            if c == Alpha
                upload_to_vao!(vao, comp, vec) do a, e
                    if e in a
                        return @inbounds vis[e].visible ? a[e] : Alpha(0.0)
                    else
                        return @inbounds vis[e].visible ? Alpha(1.0) : Alpha(0.0)
                    end
                end
            else
                upload_to_vao!(vao, comp, vec)
            end
        end
    end
end
