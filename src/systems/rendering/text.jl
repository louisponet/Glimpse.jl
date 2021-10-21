using FreeTypeAbstraction: FTFont, FT_Get_Char_Index,hadvance, leftinkbound, inkwidth, get_extent, ascender, descender 

# Taken from JuliaPlots/AbstractPlotting.jl

mutable struct TextureAtlas
    rectangle_packer::RectanglePacker
    mapping::Dict{Any, Int} # styled glyph to index in sprite_attributes
    index::Int
    data::Matrix{Float16}
    # rectangles we rendered our glyphs into in normalized uv coordinates
    uv_rectangles::Vector{Vec4f0}
end

Base.size(atlas::TextureAtlas) = size(atlas.data)

@enum GlyphResolution High Low

const TEXTURE_RESOLUTION = Ref((2048, 2048))
const CACHE_RESOLUTION_PREFIX = Ref("high")

const HIGH_PIXELSIZE = 64
const LOW_PIXELSIZE = 32

const PIXELSIZE_IN_ATLAS = Ref(HIGH_PIXELSIZE)

function size_factor()
    return DOWN_SAMPLE_HIGH / DOWN_SAMPLE_FACTOR[]
end

function set_glyph_resolution!(res::GlyphResolution)
    if res == High
        TEXTURE_RESOLUTION[] = (2048, 2048)
        CACHE_RESOLUTION_PREFIX[] = "high"
        PIXELSIZE_IN_ATLAS[] = HIGH_PIXELSIZE
    else
        TEXTURE_RESOLUTION[] = (1024, 1024)
        CACHE_RESOLUTION_PREFIX[] = "low"
        PIXELSIZE_IN_ATLAS[] = LOW_PIXELSIZE
    end
end

function TextureAtlas(initial_size = TEXTURE_RESOLUTION[])
    return TextureAtlas(
        RectanglePacker(Rect2D(0, 0, initial_size...)),
        Dict{Tuple{Char, String}, Int}(),
        1,
        zeros(Float16, initial_size...),
        Vec4f0[],
    )
end

function get_cache_path()
    return abspath(
        asset_path("fonts", ".cache",
        "texture_atlas_$(CACHE_RESOLUTION_PREFIX[]).jls"
    ))
end

const _default_font = FTFont[]
const _alternative_fonts = FTFont[]

function default_font()
    if isempty(_default_font)
        push!(_default_font, FTFont(asset_path("fonts", "DejaVuSans.ttf")))
    end
    _default_font[]
end

function alternative_fonts()
    if isempty(_alternative_fonts)
        append!(_alternative_fonts, FTFont.(asset_path.(("fonts",), searchdir(asset_path("fonts")))))
    end
    return _alternative_fonts
end

function load_ascii_chars!(atlas)
    # for c in '\u0000':'\u00ff' #make sure all ascii is mapped linearly
    #     insert_glyph!(atlas, c, default_font())
    # end
    # for c in 'a':'z'
    #     insert_glyph!(atlas, c, default_font())
    # end
    for c in 'A':'Z'
        insert_glyph!(atlas, c, default_font())
    end
    for c in '0':'9'
        insert_glyph!(atlas, c, default_font())
    end
end

function cached_load()
    if isfile(get_cache_path())
        try
            return open(get_cache_path()) do io
                dict = Serialization.deserialize(io)
                fields = map(fieldnames(TextureAtlas)) do n
                    v = dict[n]
                    isa(v, Vector) ? copy(v) : v # otherwise there seems to be a problem with resizing
                end
                TextureAtlas(fields...)
            end
        catch e
            @info("You can likely ignore the following warning, if you just switched Julia versions for Makie")
            @warn(e)
            rm(get_cache_path())
        end
    end
    atlas = TextureAtlas()
    @info("Makie/AbstractPlotting is caching fonts, this may take a while. Needed only on first run!")
    load_ascii_chars!(atlas)
    to_cache(atlas) # cache it
    return atlas
end

function to_cache(atlas)
    if !ispath(dirname(get_cache_path()))
        mkpath(dirname(get_cache_path()))
    end
    open(get_cache_path(), "w") do io
        dict = Dict(map(fieldnames(typeof(atlas))) do name
            name => getfield(atlas, name)
        end)
        Serialization.serialize(io, dict)
    end
end

const global_texture_atlas = Base.RefValue{TextureAtlas}()

function get_texture_atlas()
    if isassigned(global_texture_atlas) && size(global_texture_atlas[]) == TEXTURE_RESOLUTION[]
        global_texture_atlas[]
    else
        global_texture_atlas[] = cached_load() # initialize only on demand
        global_texture_atlas[]
    end
end


"""
    find_font_for_char(c::Char, font::FTFont)
Finds the best font for a character from a list of fallback fonts, that get chosen
if `font` can't represent char `c`
"""
function find_font_for_char(c::Char, font::FTFont)
    FT_Get_Char_Index(font, c) != 0 && return font
    for afont in alternative_fonts()
        if FT_Get_Char_Index(afont, c) != 0
            return afont
        end
    end
    error("Can't represent character $(c) with any fallback font nor $(font.family_name)!")
end

function glyph_index!(atlas::TextureAtlas, c::Char, font::FTFont)
    if FT_Get_Char_Index(font, c) == 0
        for afont in alternative_fonts()
            if FT_Get_Char_Index(afont, c) != 0
                font = afont
            end
        end
    end
    return insert_glyph!(atlas, c, font)
end

function glyph_uv_width!(atlas::TextureAtlas, c::Char, font::FTFont)
    return atlas.uv_rectangles[glyph_index!(atlas, c, font)]
end

function glyph_uv_width!(c::Char)
    return glyph_uv_width!(get_texture_atlas(), c, defaultfont())
end

function glyph_boundingbox(c::Char, font::FTFont, pixelsize)
    if FT_Get_Char_Index(font, c) == 0
        for afont in alternativefonts()
            if FT_Get_Char_Index(afont, c) != 0
                font = afont
                break
            end
        end
    end
    bb, ext = FreeTypeAbstraction.metrics_bb(c, font, pixelsize)
    return bb
end

function insert_glyph!(atlas::TextureAtlas, glyph::Char, font::FTFont)
    return get!(atlas.mapping, (glyph, FreeTypeAbstraction.fontname(font))) do
        downsample = 5 # render font 5x larger, and then downsample back to desired pixelsize
        pad = 8 # padd rendered font by 6 pixel in each direction
        uv_pixel = render(atlas, glyph, font, downsample, pad)
        tex_size = Vec2f0(size(atlas.data) .- 1) # starts at 1

        idx_left_bottom = minimum(uv_pixel)# 0 based!!!
        idx_right_top = maximum(uv_pixel)

        # include padding
        left_bottom_pad = idx_left_bottom .+ pad .- 1
        # -1 for indexing offset
        right_top_pad = idx_right_top .- pad

        # transform to normalized texture coordinates
        uv_left_bottom_pad = (left_bottom_pad) ./ tex_size
        uv_right_top_pad =  (right_top_pad) ./ tex_size

        uv_offset_rect = Vec4f0(uv_left_bottom_pad..., uv_right_top_pad...)
        i = atlas.index
        push!(atlas.uv_rectangles, uv_offset_rect)
        atlas.index = i + 1
        return i
    end
end

"""
    sdistancefield(img, downsample, pad)
Calculates a distance fields, that is downsampled `downsample` time,
with a padding applied of `pad`.
The padding is in units after downscaling!
"""
function sdistancefield(img, downsample, pad)
    # we pad before downsampling, so we need to have `downsample` as much padding
    pad = downsample * pad
    # padd the image
    padded_size = size(img) .+ 2pad

    # for the downsampling, we need to make sure that
    # we can divide the image size by `downsample` without reminder
    dividable_size = ceil.(Int, padded_size ./ downsample) .* downsample

    in_or_out = fill(false, dividable_size)
    # the size we fill the image up to
    wend, hend = size(img) .+ pad
    in_or_out[pad+1:wend, pad+1:hend] .= img .> (0.5 * 255)

    yres, xres = dividable_size .÷ downsample
    # divide by downsample to normalize distances!
    return Float16.(sdf(in_or_out, xres, yres) ./ downsample)
end

function render(atlas::TextureAtlas, glyph::Char, font, downsample=5, pad=6)
    #select_font_face(cc, font)
    if glyph == '\n' # don't render  newline
        glyph = ' '
    end
    # the target pixel size of our distance field
    pixelsize = PIXELSIZE_IN_ATLAS[]
    # we render the font `downsample` sizes times bigger
    bitmap, extent = renderface(font, glyph, pixelsize * downsample)
    # Our downsampeld & padded distancefield
    sd = sdistancefield(bitmap, downsample, pad)
    rect = Area(0, 0, size(sd)...)
    uv = push!(atlas.rectangle_packer, rect) # find out where to place the rectangle
    uv == nothing && error("texture atlas is too small. Resizing not implemented yet. Please file an issue at Makie if you encounter this") #TODO resize surface
    # write distancefield into texture
    atlas.data[uv.area] = sd
    # return the area we rendered into!
    return uv.area
end

function layout_text(
        string::AbstractString, textsize::Union{AbstractVector, Number},
        font, align, justification=0.5, lineheight=1.0
    )

    offset_vec = alignment2num.(align)
    ft_font = font
    rscale = textsize

    atlas = get_texture_atlas()
    pos = zero(Vec2f0)

    glyphpos = glyph_positions(string, font, textsize, offset_vec[1],
        offset_vec[2], lineheight, justification)

    positions = Vec2f0[]
    for (i, group) in enumerate(glyphpos)
        for gp in group
            # rotate around the alignment point (this is now at [0, 0, 0])
            push!(positions, pos .+ gp) # TODO why division by 4 necessary?
        end
        # between groups, push a random point for newline, it doesn't matter
        # what it is
        if i < length(glyphpos)
            push!(positions, zero(Vec2f0))
        end
    end

    return positions
end

function glyph_positions(str::AbstractString, font, fontscale_px, halign, valign, lineheight_factor, justification)

    isempty(str) && return Vec2f0[]


    linebreak_indices = (i for (i, c) in enumerate(str) if c == '\n')

    groupstarts = [1; linebreak_indices .+ 1]
    groupstops = [linebreak_indices .- 1; length(str)]

    char_groups = map(groupstarts, groupstops) do start, stop
        str[start:stop]
    end

    extents = map(char_groups) do group
        # TODO: scale as SVector not Number
        [get_extent(font, char) .* SVector(fontscale_px, fontscale_px) for char in group]
    end

    # add or subtract kernings?
    xs = map(extents) do extgroup
        cumsum([isempty(extgroup) ? 0.0 : -leftinkbound(extgroup[1]); hadvance.(extgroup[1:end-1])])
    end

    # each linewidth is the last origin plus inkwidth
    linewidths = last.(xs) .+ [isempty(extgroup) ? 0.0 : inkwidth(extgroup[end]) for extgroup in extents]
    maxwidth = maximum(linewidths)

    width_differences = maxwidth .- linewidths

    xs_justified = map(xs, width_differences) do xsgroup, wd
        xsgroup .+ wd * justification
    end

    # make lineheight a multiple of the largest lineheight in each line
    lineheights = map(char_groups) do group
        # guard from empty reduction
        isempty(group) && return 0f0
        Float32(font.height / font.units_per_EM * lineheight_factor * fontscale_px)
    end

    # how to define line height relative to font size?
    ys = cumsum([0; -lineheights[2:end]])


    # x alignment
    xs_aligned = [xsgroup .- halign * maxwidth for xsgroup in xs_justified]

    # y alignment
    # first_max_ascent = maximum(hbearing_ori_to_top, extents[1])
    # last_max_descent = maximum(x -> inkheight(x) - hbearing_ori_to_top(x), extents[end])

    first_line_ascender = ascender(font) * fontscale_px

    last_line_descender = descender(font) * fontscale_px
        
    overall_height = first_line_ascender - ys[end] - last_line_descender

    ys_aligned = ys .- first_line_ascender .+ (1 - valign) .* overall_height

    # we are still operating in freetype units, let's convert to the chosen scale by dividing with 64
    return [Vec2f0.(xsgroup, y) for (xsgroup, y) in zip(xs_aligned, ys_aligned)]
end

function text_bb(str, font, size)
    positions = layout_text(
        str, Point2f0(0), size,
        font, Vec2f0(0), Quaternionf0(0,0,0,1), Mat4f0(I), 0.5, 1.0
    )

    scale = widths.(first.(FreeTypeAbstraction.metrics_bb.(collect(str), font, size)))
    return union(FRect3D(positions),  FRect3D(positions .+ to_ndim.(Point3f0, scale, 0)))
end


make_iter(x) = repeated(x)
make_iter(x::AbstractArray) = x

function get_iter(defaultfunc, dictlike, key)
    make_iter(get(defaultfunc, dictlike, key))
end

function alignment2num(x::Symbol)
    (x == :center) && return 0.5f0
    (x in (:left, :bottom)) && return 0.0f0
    (x in (:right, :top)) && return 1.0f0
    0.0f0 # 0 default, or better to error?
end

@component struct FontStorage
    atlas       ::TextureAtlas
    storage_fbo ::GLA.FrameBuffer #All Glyphs should be stored in the first color attachment
end

function FontStorage()
    atlas = get_texture_atlas()
    fbo   = GLA.FrameBuffer(size(atlas.data), GLA.Texture(atlas.data, minfilter=:linear, magfilter=:linear, anisotropic=16f0))
    return FontStorage(atlas, fbo)
end

@render_program TextProgram
shaders(::Type{TextProgram}) = [load_shader("sprites.geom"),
                                load_shader("sprites.vert"),
                                load_shader("distance_shape.frag")]

@vao TextVao

struct TextUploader <: System end
Overseer.requested_components(::TextUploader) = (Text, TextVao, TextProgram, FontStorage)

function Overseer.prepare(::TextUploader, dio::Diorama)
    e = Entity(dio[DioEntity], 1)
    if isempty(dio[TextProgram])
        dio[e] = TextProgram(Program(text_shaders()))
    end
    if isempty(dio[FontStorage])
        # dio[e] = FontStorage()
    end
end

function Overseer.update(::TextUploader, m::AbstractLedger)
    text = m[Text]
    vao  = m[TextVao]
    prog = singleton(m, TextProgram)
    ucolor = m[UniformColor]
    spatial= m[Spatial]
    vis = m[Visible]
    atlas = get_texture_atlas()
    for e in @entities_in(text && spatial && ucolor)
        t = text[e]
        offset_width, uv_texture_bbox  = to_gl_text(t, atlas)
        nsprites = length(t.str)
        if !(e ∈ vao) || nsprites > length(vao[e])
            vao[e] = TextVao(VertexArray(generate_buffers(prog.program,
                                   GLint(0),
                                   color = fill(ucolor[e].color, nsprites),
                                   rotation = fill(Vec4f0(0), nsprites),
                                   offset_width    = offset_width,
                                   uv_texture_bbox = uv_texture_bbox), GL_POINTS))
        else
            GLA.upload!(vao[e], color       = fill(ucolor[e].color, nsprites),
                            rotation        = fill(Vec4f0(0), nsprites),
                            offset_width    = offset_width,
                            uv_texture_bbox = uv_texture_bbox)
        end
        if !(e in vis)
            vis[e] = Visible()
        end
    end
end

to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t, storage.atlas)
to_gl_text(t::Text, atlas) = to_gl_text(t.str, t.font_size, t.font, t.align, atlas)

function to_gl_text(string::AbstractString, textsize, font, align::Tuple{Symbol, Symbol}, atlas)
    # rscale          = Float32(textsize)
    chars           = Vector{Char}(string)
    scale           = Vec2f0[]
    offset          = Vec2f0[]
    for c in string
        glyph_bb, extent = FreeTypeAbstraction.metrics_bb(c, font, textsize)
        push!(scale, widths(glyph_bb))
        push!(offset, minimum(glyph_bb))
    end
    # scale           = Vec2f0.(glyph_scale!.(Ref(atlas), chars, (font,), rscale))
    positions2d     = layout_text(string, textsize, font, align)

    # aoffset         = align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)

    uv_offset_width = glyph_uv_width!.(Ref(atlas), chars, (font,))
    out_uv_offset_width= Vec4f0[]
    for uv in uv_offset_width
        push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3], uv[4] ))
    end
    out_pos_scale = Vec4f0[]
    for (p, sc) in zip(positions2d .+ offset, scale)
        push!(out_pos_scale, Vec4f0(p[1], p[2], sc[1], sc[2]))
    end
    return out_pos_scale, out_uv_offset_width
end

struct TextRenderer <: AbstractRenderSystem end

Overseer.requested_components(::TextRenderer) =
    (Spatial, UniformColor, Camera3D, TextVao, Text,
        TextProgram, IOTarget, FontStorage)

function Overseer.update(::TextRenderer, m::AbstractLedger)
    spat           = m[Spatial]
    prog           = singleton(m, TextProgram)
    camera         = singleton(m, Camera3D)
    vao            = m[TextVao]
    iofbo          = singleton(m, Canvas)
    persp_mat      = camera.projview
    projection_mat = camera.proj
    text           = m[Text]
    vis            = m[Visible]
    wh = size(iofbo)

    glDisable(GL_DEPTH_TEST)
    glDepthFunc(GL_ALWAYS)
    glDisableCullFace()
    
    glEnablei(GL_BLEND, 0)
    glDisablei(GL_BLEND, 1)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    
    bind(iofbo)
    draw(iofbo)

    bind(prog)
    gluniform(prog, :resolution, Vec2f0(wh))
    gluniform(prog, :projview, persp_mat)
    gluniform(prog, :projection, projection_mat)

    #Absolutely no clue why this needs to be here?...
    if isempty(m[FontStorage])
        fontstorage = FontStorage()
        m[Entity(m[DioEntity],1)] = fontstorage
    else
        fontstorage = singleton(m, FontStorage)
    end
    glyph_fbo = fontstorage.storage_fbo

    # Fragment uniforms
    gluniform(prog, :distancefield, 0, color_attachment(glyph_fbo, 1))
    gluniform(prog, :shape, 3)
    #TODO make this changeable
    # gluniform(prog, :stroke_color, zero(Vec4f0))
    # gluniform(prog, :glow_color, zero(Vec4f0))
    gluniform(prog, :stroke_width, 0f0)
    gluniform(prog, :glow_width, 0f0)
    gluniform(prog, :billboard, true)
    gluniform(prog, :scale_primitive, true)
    for e in @entities_in(vao && spat && text)
        e_vao, e_spat, e_text = vao[e], spat[e], text[e]
        if vis[e].visible
            gluniform(prog,:model, m[ModelMat][e].modelmat)
            gluniform(prog,:origin, e_text.offset)
            bind(e_vao)
            draw(e_vao)
        end
    end
    glDisablei(GL_BLEND, 0)
    glEnablei(GL_BLEND, 1)
end

