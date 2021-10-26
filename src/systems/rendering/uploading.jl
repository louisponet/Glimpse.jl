struct Uploader <: System end

Overseer.requested_components(::Uploader) =
    (Mesh, BufferColor, DefaultVao, DefaultProgram, LineVao, LineProgram, PeelingProgram, PeelingVao, LineGeometry, Alpha, Visible)

shaders(::Type{DefaultProgram}) = default_shaders()
shaders(::Type{PeelingProgram}) = peeling_shaders()
shaders(::Type{InstancedDefaultProgram}) = instanced_default_shaders()
shaders(::Type{InstancedPeelingProgram}) = instanced_peeling_shaders()
shaders(::Type{PeelingCompositingProgram}) = peeling_compositing_shaders()
shaders(::Type{CompositingProgram}) = compositing_shaders()
shaders(::Type{BlendProgram}) = blending_shaders()
shaders(::Type{FXAAProgram})  = fxaa_shaders()
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
    line_vao    = m[LineVao]
    peeling_prog= singleton(m, PeelingProgram)
    default_prog= singleton(m, DefaultProgram)
    line_prog   = singleton(m, LineProgram)
    uc = singleton(m, UpdatedComponents)
    alpha = m[Alpha]

    #Buffer color entities are always not instanced
    for e in @entities_in(mesh && bcolor && !default_vao && !peeling_vao)
        gen_vao = prog -> begin
    		buffers = [generate_buffers(prog, e.mesh);
    	               generate_buffers(prog, GEOMETRY_DIVISOR, color=e.color)]
            return VertexArray(buffers, map(x-> x.-GLint(1), faces(e.mesh)))
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
            color_attach = BufferAttachmentInfo(:color, color_loc, Buffer(color_vec), GEOMETRY_DIVISOR)
            points_attach = BufferAttachmentInfo(:vertices, vert_loc, Buffer(e.points), GEOMETRY_DIVISOR)
            line_vao[e] = LineVao(VertexArray([points_attach, color_attach], GL_LINE_STRIP_ADJACENCY))
        else 
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :vertices).buffer, e.points)
            GLA.upload_data!(GLA.bufferinfo(line_vao[e].vertexarray, :color).buffer, color_vec)
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
    idc = m[Selectable]
    mesh = m[Mesh]
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
    
    if n_default == length(default_vao) && n_peeling == length(peeling_vao)
        return
    end

    max_entities = maximum(mesh.group_size)
    modelmats    = Vector{Mat4f0}(undef,   max_entities) 
    materials    = Vector{Material}(undef, max_entities) 
    ids          = Vector{Entity}(undef,   max_entities)
    colors       = Vector{RGBf0}(undef,    max_entities)
    idcolors     = Vector{RGBf0}(undef,    max_entities)
    alphas       = Vector{Float32}(undef,  max_entities)
    
    for (i, m) in enumerate(mesh)
        default_it = @entities_in(entity_group(mesh, i) && ucolor && modelmat && material && !alpha)
        peeling_it = @entities_in(entity_group(mesh, i) && ucolor && modelmat && material && alpha)
        for (it, vao, prog) in zip((default_it, peeling_it), (default_vao, peeling_vao), (default_prog, peeling_prog))
            tot = length(it)
            if i <= length(vao.group_size) && tot == vao.group_size[i]
                # Nothing to be done for this meshgroup
                continue
            end

            for (ie, e) in enumerate(it)
                modelmats[ie] = e.modelmat
                materials[ie] = e[Material]
                ids[ie] = e.e
                colors[ie] = e[UniformColor].color
                if e in idc
                    idcolors[ie] = idc[e].color
                else
                    idcolors[ie] = RGBf0(1,1,1)
                end
                if !(e in vis)
                    vis[e] = Visible()
                end
                if e in alpha
                    alphas[ie] = vis[e].visible ? alpha[e].α : 0
                else
                    alphas[ie] = vis[e].visible ? 1 : 0
                end
            end
            @show i
            @show tot
            @show ids[1]
                
            
            if (tot > 0 && length(vao.group_size) < i)
                # Mesh needs to be uploaded
                buffers = [generate_buffers(prog, m.mesh);
                           generate_buffers(prog, GLA.UNIFORM_DIVISOR,
                                        color    = view(colors, 1:tot),
                                        modelmat = view(modelmats, 1:tot),
                                        material  = view(materials, 1:tot),
                                        object_id_color = view(idcolors, 1:tot),
                                        alpha = view(alphas, 1:tot)
                                        )]
                vao[ids[1]] = InstancedDefaultVao(VertexArray(buffers, map(x->x.-GLint(1), m.mesh.faces), tot))
                for e in ids[2:tot]
                    vao[e] = ids[1]
                end
                
                # mesh needs to be uploaded
            elseif i <= length(vao.group_size) && tot > vao.group_size[i]
                # buffers need to be reuploaded because extra entities were added
                buffers = generate_buffers(prog, GLA.UNIFORM_DIVISOR,
                                        color    = view(colors, 1:tot),
                                        modelmat = view(modelmats, 1:tot),
                                        material  = view(materials, 1:tot),
                                        object_id_color = view(idcolors, 1:tot),
                                        alpha = view(alphas, 1:tot)
                                        )
                tvao = vao.data[i]
                #TODO handle this
            end
        end
    end
end

struct UniformUploader <: System end

Overseer.requested_components(::UniformUploader) =
    (InstancedDefaultVao, InstancedPeelingVao, ModelMat, Selectable, UniformColor, UpdatedComponents)

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

function Overseer.update(::UniformUploader, m::AbstractLedger)
    uc = m[UpdatedComponents][1]
    mat = m[ModelMat]
    matsize = sizeof(eltype(mat))
    ucolor = m[UniformColor]
    material = m[Material]
    vis = m[Visible]
    alpha = m[Alpha]
    for vao in (m[InstancedDefaultVao], m[InstancedPeelingVao])
        reupload_uniform_component = (comp, comp_shader_symbol) -> begin
            it1 = @entities_in(vao && comp)
            for tvao in vao.data
                if comp_shader_symbol == :visible
                    comp_vector = Alpha[]
                    for e in it1
                        e_vao, e_comp =
                            vao[e], comp[e]

                        if e_vao === tvao
                            if e_comp.visible
                                if e in alpha
                                    push!(comp_vector, alpha[e])
                                else
                                    push!(comp_vector, Alpha(1))
                                end
                            else
                                push!(comp_vector, Alpha(0))
                            end
                        end
                    end
                    comp_shader_symbol = :alpha
                else
                    comp_vector = eltype(comp)[]
                    for e in it1
                        e_vao, e_comp = vao[e], comp[e]
                        if e_vao === tvao
                            push!(comp_vector, e_comp)
                        end
                    end
                end
                if !isempty(comp_vector)
                    binfo = GLA.bufferinfo(tvao.vertexarray, comp_shader_symbol)
                    datsize = sizeof(eltype(comp_vector))
                    if binfo !== nothing
                        GLA.bind(binfo.buffer)
                        s = length(comp_vector) * datsize
                        glBufferData(binfo.buffer.buffertype, s, pointer(comp_vector, 1), binfo.buffer.usage)
                        GLA.unbind(binfo.buffer)
                    end
                end
            end
        end
        if ModelMat in uc.components
            reupload_uniform_component(m[ModelMat], :modelmat)
        end
        if UniformColor in uc.components
            reupload_uniform_component(m[UniformColor], :color)
        end
        if Material in uc.components
            reupload_uniform_component(m[Material], :material)
        end
        # if Alpha in uc.components
        #     reupload_uniform_component(m[Alpha], :alpha)
        # end    
        reupload_uniform_component(m[Visible], :visible)
    end
end
