using FreeTypeAbstraction: FTFont, FT_Get_Char_Index
# Taken from JuliaPlots/AbstractPlotting.jl

mutable struct TextureAtlas
    rectangle_packer::RectanglePacker
    mapping::Dict{Any, Int} # styled glyph to index in sprite_attributes
    index::Int
    data::Matrix{Float16}
    attributes::Vector{Vec4f0}
    scale::Vector{Vec2f0}
    extent::Vector{FontExtent{Float64}}
end

Base.size(atlas::TextureAtlas) = size(atlas.data)

@enum GlyphResolution High Low

const TEXTURE_RESOLUTION = Ref((2048, 2048))
const CACHE_RESOLUTION_PREFIX = Ref("high")

const DOWN_SAMPLE_FACTOR = Ref(50)
const DOWN_SAMPLE_HIGH = 50
const DOWN_SAMPLE_LOW = 30

function size_factor()
    return DOWN_SAMPLE_HIGH / DOWN_SAMPLE_FACTOR[]
end

function set_glyph_resolution!(res::GlyphResolution)
    if res == High
        TEXTURE_RESOLUTION[] = (2048, 2048)
        CACHE_RESOLUTION_PREFIX[] = "high"
        DOWN_SAMPLE_FACTOR[] = DOWN_SAMPLE_HIGH
    else
        TEXTURE_RESOLUTION[] = (1024, 1024)
        CACHE_RESOLUTION_PREFIX[] = "low"
        DOWN_SAMPLE_FACTOR[] = DOWN_SAMPLE_LOW
    end
end

function TextureAtlas(initial_size = TEXTURE_RESOLUTION[])
    return TextureAtlas(
        RectanglePacker(Area(0, 0, initial_size...)),
        Dict{Any, Int}(),
        1,
        zeros(Float16, initial_size...),
        Vec4f0[],
        Vec2f0[],
        FontExtent{Float64}[]
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
    for c in '\u0000':'\u00ff' #make sure all ascii is mapped linearly
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
            @warn(e)
            rm(get_cache_path())
        end
    end
    atlas = TextureAtlas()
    @info("Glimpse is caching fonts, this may take a while. Needed only on first run!")
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

glyph_scale!(c::Char, scale) = glyph_scale!(get_texture_atlas(), c, default_font(), scale)
glyph_uv_width!(c::Char) = glyph_uv_width!(get_texture_atlas(), c, default_font())


function glyph_uv_width!(atlas::TextureAtlas, c::Char, font::FTFont)
    atlas.attributes[glyph_index!(atlas, c, font)]
end

function glyph_scale!(atlas::TextureAtlas, c::Char, font::FTFont, scale)
    atlas.scale[glyph_index!(atlas, c, font)] .* (scale * 0.02) .* size_factor()
end

function glyph_extent!(atlas::TextureAtlas, c::Char, font::FTFont)
    atlas.extent[glyph_index!(atlas, c, font)]
end

function bearing(extent)
    Point2f0(
        extent.horizontal_bearing[1],
        -(extent.scale[2] - extent.horizontal_bearing[2])
    )
end

function glyph_bearing!(atlas::TextureAtlas, c::Char, font::FTFont, scale)
    bearing(atlas.extent[glyph_index!(atlas, c, font)]) .* Point2f0(scale * 0.02) .* size_factor()
end

function glyph_advance!(atlas::TextureAtlas, c::Char, font::FTFont, scale)
    atlas.extent[glyph_index!(atlas, c, font)].advance .* (scale * 0.02) .* size_factor()
end

function insert_glyph!(atlas::TextureAtlas, glyph::Char, font::FTFont)
    return get!(atlas.mapping, (glyph, font)) do
        uv, extent, width_nopadd, pad = render(atlas, glyph, font)
        tex_size = Vec2f0(size(atlas.data))
        uv_start = Vec2f0(uv.origin...)
        uv_width = Vec2f0(uv.widths...)
        real_start = uv_start .+ pad .- 1 # include padding
        # padd one additional pixel
        relative_start = real_start ./ tex_size # use normalized texture coordinates
        relative_width = (real_start .+ width_nopadd .+ 2) ./ tex_size

        uv_offset_width = Vec4f0(relative_start..., relative_width...)
        i = atlas.index
        push!(atlas.attributes, uv_offset_width)
        push!(atlas.scale, Vec2f0(width_nopadd .+ 2))
        push!(atlas.extent, extent)
        atlas.index = i + 1
        return i
    end
end

function sdistancefield(img, downsample = 8, pad = 8*downsample)
    w, h = size(img)
    wpad = 0; hpad = 0;
    while w % downsample != 0
        w += 1
    end
    while h % downsample != 0
        h += 1
    end
    w, h = w + 2pad, h + 2pad #pad this, to avoid cuttoffs

    in_or_out = Matrix{Bool}(undef, w, h)
    @inbounds for i=1:w, j=1:h
        x, y = i-pad, j-pad
        in_or_out[i,j] = checkbounds(Bool, img, x, y) && img[x,y] > 0.5 * 255
    end
    yres, xres = div(w, downsample), div(h, downsample)
    sd = sdf(in_or_out, xres, yres)
    Float16.(sd)
end

function render(atlas::TextureAtlas, glyph::Char, font, downsample = 5, pad = 8)
    #select_font_face(cc, font)
    if glyph == '\n' # don't render  newline
        glyph = ' '
    end
    DF = DOWN_SAMPLE_FACTOR[]
    bitmap, extent = renderface(font, glyph, DF*downsample)
    sd = sdistancefield(bitmap, downsample, downsample*pad)
    sd = sd ./ downsample;
    extent = (extent ./ Vec2f0(downsample))
    rect = Area(0, 0, size(sd)...)
    uv = push!(atlas.rectangle_packer, rect) #find out where to place the rectangle
    uv == nothing && error("texture atlas is too small. Resizing not implemented yet. Please file an issue at GLVisualize if you encounter this") #TODO resize surface
    atlas.data[uv.area] = sd
    uv.area, extent, Vec2f0(size(bitmap)) ./ (downsample), pad
end

make_iter(x) = repeated(x)
make_iter(x::AbstractArray) = x

function get_iter(defaultfunc, dictlike, key)
    make_iter(get(defaultfunc, dictlike, key))
end

function getposition(text, text2, fonts, scales, start_pos)
    calc_position(text2, start_pos, scales, fonts, text.text.atlas)
end
function getoffsets(text, text2, fonts, scales)
    calc_offset(text2, scales, fonts, text.text.atlas)
end


function calc_position(
        last_pos, start_pos,
        atlas, glyph, font,
        scale, lineheight = 1.5
    )
    advance_x, advance_y = glyph_advance!(atlas, glyph, font, scale)
    if glyph == '\n'
        return Point2f0(start_pos[1], last_pos[2] - advance_y * lineheight) #reset to startx
    else
        return last_pos + Point2f0(advance_x, 0)
    end
end

function calc_position(glyphs, start_pos, scales, fonts, atlas)
    positions = zeros(Point2f0, length(glyphs))
    last_pos  = Point2f0(start_pos)
    # s, f = iter_or_array(scales), iter_or_array(fonts)
    iter = enumerate(zip(glyphs, Iterators.repeated(scales), Iterators.repeated(fonts)))
    next = iterate(iter)
    if next !== nothing
        (i, (char, scale, font)), state = next
        first_bearing = glyph_bearing!(atlas, char, font, scale)
        while next !== nothing
            (i, (char, scale, font)), state = next
            next = iterate(iter, state)
            char == '\r' && continue # stupid windows!
            # we draw the glyph at the last position we calculated
            bearing = glyph_bearing!(atlas, char, font, scale)
            # we substract the first bearing, since we want to start at
            # startposition without any additional offset!
            positions[i] = last_pos .+ bearing .- first_bearing
            # then we add the advance for the next glyph to start
            last_pos = calc_position(last_pos, start_pos, atlas, char, font, scale)
        end
    end
    return positions
end

function calc_offset(glyphs, scales, fonts, atlas)
    offsets = fill(Point2f0(0.0), length(glyphs))
    s, f = iter_or_array(scales), iter_or_array(fonts)
    c1 = first(glyphs)
    for (i, (c2, scale, font)) in enumerate(zip(glyphs, s, f))
        c2 == '\r' && continue # stupid windows!
        offsets[i] = Point2f0(glyph_bearing!(atlas, c2, font, scale))
        c1 = c2
    end
    return offsets # bearing is the glyph offset
end

function align_offset(startpos, lastpos, atlas, rscale, font, align)
    xscale, yscale = glyph_scale!('X', rscale)
    xmove = (lastpos-startpos)[1] + xscale
    if isa(align, Vec)
        return -Vec2f0(xmove, yscale) .* align
    elseif align == :top
        return -Vec2f0(xmove/2f0, yscale)
    elseif align == :right
        return -Vec2f0(xmove, yscale/2f0)
    else
        error("Align $align not known")
    end
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
    fbo   = GLA.FrameBuffer(size(atlas.data), (eltype(atlas.data), ), [atlas.data]; minfilter=:linear, magfilter=:linear, anisotropic=16f0)
    return FontStorage(atlas, fbo)
end

@render_program TextProgram
shaders(::Type{TextProgram}) = [load_shader_source("sprites.geom"),
                                load_shader_source("sprites.vert"),
                                load_shader_source("distance_shape.frag")]

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
	atlas = get_texture_atlas()
	for e in @entities_in(text && spatial && ucolor)
    	t=text[e]
		offset_width, uv_texture_bbox  = to_gl_text(t, atlas)
		nsprites = length(t.str)
		if !(e ∈ vao) || nsprites > length(vao[e])
    		vao[e] = TextVao(VertexArray(generate_buffers(prog.program,
                                   GLint(0),
                                   color = fill(ucolor[e].color, nsprites),
                                   rotation = fill(Vec4f0(0), nsprites),
                                   offset_width    = offset_width,
                                   uv_texture_bbox = uv_texture_bbox), GL_POINTS), true)
        else
            GLA.upload!(vao[e], color       = fill(ucolor[e].color, nsprites),
                            rotation        = fill(Vec4f0(0), nsprites),
                            offset_width    = offset_width,
                            uv_texture_bbox = uv_texture_bbox)
        end
	end
end

to_gl_text(t::Text, storage::FontStorage) = to_gl_text(t, storage.atlas)
to_gl_text(t::Text, atlas) = to_gl_text(t.str, t.font_size, t.font, t.align, atlas)

function to_gl_text(string::AbstractString, textsize, font, align::Symbol, atlas)
    rscale          = Float32(textsize)
    chars           = Vector{Char}(string)

    scale           = Vec2f0.(glyph_scale!.(Ref(atlas), chars, (font,), rscale))
    positions2d     = calc_position(string, Point2f0(0), rscale, font, atlas)
    # @show positions2d

    aoffset         = align_offset(Point2f0(0), positions2d[end], atlas, rscale, font, align)

    uv_offset_width = glyph_uv_width!.(Ref(atlas), chars, (font,))
    out_uv_offset_width= Vec4f0[]
    for uv in uv_offset_width
	    push!(out_uv_offset_width, Vec4f0(uv[1], uv[2], uv[3], uv[4] ))
    end
    out_pos_scale = Vec4f0[]
    for (p, sc) in zip(positions2d .+ (aoffset,), scale)
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
	iofbo          = singleton(m, IOTarget)
	persp_mat      = camera.projview
	projection_mat = camera.proj
	text           = m[Text]
	wh = size(iofbo)

	glDisable(GL_DEPTH_TEST)
	glDepthFunc(GL_ALWAYS)
	glDisableCullFace()

    bind(iofbo)
    draw(iofbo)

	bind(prog)
	set_uniform(prog, :resolution, Vec2f0(wh))
    set_uniform(prog, :projview, persp_mat)
    set_uniform(prog, :projection, projection_mat)

    #Absolutely no clue why this needs to be here?...
	if isempty(m[FontStorage])
    	fontstorage = FontStorage()
    	m[Entity(m[DioEntity],1)] = fontstorage
	else
    	fontstorage = singleton(m, FontStorage)
	end
	glyph_fbo = fontstorage.storage_fbo

    # Fragment uniforms
    # GLA.gpu_setindex!(color_attachment(glyph_fbo, 1), singleton(m, FontStorage).atlas.data, 1:size(singleton(m, FontStorage).atlas.data, 1), 1:size(singleton(m, FontStorage).atlas.data, 2))
	set_uniform(prog, :distancefield, 0, color_attachment(glyph_fbo, 1))
	set_uniform(prog, :shape, 3)
	#TODO make this changeable
	set_uniform(prog, :stroke_width, 0f0)
	set_uniform(prog, :glow_width, 0f0)
	set_uniform(prog, :billboard, true)
	set_uniform(prog, :scale_primitive, false)
	for e in @entities_in(vao && spat && text)
        e_vao, e_spat, e_text = vao[e], spat[e], text[e]
        if e_vao.visible
    		set_uniform(prog,:model, m[ModelMat][e].modelmat)
    		set_uniform(prog,:origin, e_text.offset)
    		bind(e_vao)
    		draw(e_vao)
		end
	end
end

