import GLAbstraction: free!
########### Initialization
const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    return currentdio[] = x
end

Overseer.ledger(dio::Diorama) = dio.ledger

function Diorama(extra_stages::Stage...; name = :Glimpse, kwargs...) #Defaults
    m = Ledger(Stage(:start, [Timer(), EventPoller()]),
               Stage(:setup,
                     [MousePicker(), PolygonMesher(), DensityMesher(), VectorMesher(),
                      FunctionMesher(), FunctionColorizer(), IDColorGenerator(), Uploader(),
                      InstancedUploader(), TextUploader()]), extra_stages...,
               Stage(:simulation, [Oscillator(), Mover(), Editor(), UniformCalculator()]),
               Stage(:rendering,
                     [PreRenderer(), Resizer(), LineRenderer(), UniformUploader(),
                      DefaultRenderer(), DepthPeelingRenderer(), FinalRenderer(),
                      TextRenderer(), GuiRenderer()]),
               Stage(:stop, [CameraOperator(), Sleeper()]))

    #assemble all rendering, canvas and camera components
    t = Diorama(name, m, stages(m))
    e = Entity(t)
    t[UpdatedComponents][e] = UpdatedComponents()
    t[e] = DioEntity()
    t[e] = TimingData()
    fetch(glimpse_call() do
              c = Canvas(name; kwargs...)
              make_current(c)
              m[e] = c
              wh = size(c)
              m[e] = IOTarget(GLA.FrameBuffer(wh,
                                              GLA.Texture(RGBAf0, wh;
                                                          internalformat = GL_RGBA),
                                              GLA.Texture(RGBAf0, wh;
                                                          internalformat = GL_RGBA),
                                              GLA.Texture(GLA.Depth{Float32}, wh)),
                              c.background)
              m[e] = FullscreenVao()
              m[e] = UpdatedComponents(DataType[])
              m[e] = Mouse(div.(wh, 2)..., 0, 0, (0, 0), (0, 0), GLFW.MOUSE_BUTTON_1,
                           GLFW.RELEASE)
              m[e] = Keyboard(GLFW.KEY_UNKNOWN, 0, GLFW.RELEASE)
              for v in assemble_camera3d(Int32.(size(c))...)
                  m[e] = v
              end
              return Entity(t, DioEntity(), Spatial(; position = Point3f0(200.0f0)),
                            PointLight(), UniformColor(RGBf0(1.0, 1.0, 1.0)))
          end)

    fetch(glimpse_call(() -> Overseer.prepare(t)))
    return t
end

function Base.show(io::IO, d::Diorama)
    return println(io, "Diorama with $(length(entities(d))) entities.")
end
# "Darken all the lights in the dio by a certain amount"
# darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
# lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

#This is kind of like a try catch command to execute only when a valid canvas is attached to the diorama
#i.e All GL calls should be inside one of these otherwise it might be bad.
function canvas_command(command::Function, dio::Diorama, catchcommand = x -> nothing)
    canvas = dio.ledger[Canvas][1]
    if canvas !== nothing
        glimpse_call(() -> command(canvas))
    else
        glimpse_call(() -> catchcommand(canvas))
    end
end

function expose(dio::Diorama; kwargs...)
    if dio.loop === nothing
        canvas_command(dio,
                       x -> m[Entity(m[DioEntity], 1)] = Overseer.Entity(dio,
                                                                         Canvas(dio.name;
                                                                                kwargs...))) do x
            make_current(x)
            expose(x)
            return renderloop(dio)
        end
    end
    return dio
end

function Overseer.update(dio::Diorama, init = false)
    timer = singleton(dio, TimingData).timer
    mesg = init ? "Init" : "Running"
    @timeit timer mesg for stage in dio.renderloop_stages
        for sys in last(stage)
            timeit(() -> update(sys, dio), timer, string(typeof(sys)))
        end
    end
end

#TODO move control over this to diorama itself
function renderloop(dio)
    return dio.loop = canvas_command(dio) do canvas
        Overseer.prepare(dio)
        try
            @info "Initializing render..."
            update(dio, true)
            @info "Rendering..."
            while !should_close(canvas)
                pollevents(canvas)
                singleton(dio, Camera3D).locked = false
                update(dio)
                empty!(singleton(dio, UpdatedComponents))
            end
            close(canvas)
            dio.loop = nothing
        catch e
            close(canvas)
            for stage in stages(dio)
                Overseer.update(stage, dio)
            end
            throw(e)
        end
    end
end

function reload(dio::Diorama)
    close(dio)
    canvas_command(dio) do canvas
        while isopen(canvas) && dio.loop !== nothing
            sleep(0.01)
        end
        dio.reupload = true
        return expose(dio)
    end
end

function close(dio::Diorama)
    canvas_command(canvas -> should_close!(canvas, true), dio)
    if dio.loop === nothing
        canvas_command(canvas -> close(canvas), dio)
    end
end

function free!(dio::Diorama)
    close(dio)
    canvas_command(dio) do c
        for c in components(dio)
            if eltype(c) <: Vao
                for v in c
                    finalize(v)
                end
            end
        end
        finalize(c)
    end
end

isrendering(dio::Diorama) = dio.loop !== nothing

Base.size(dio::Diorama) = canvas_command(c -> windowsize(c), dio, x -> (0, 0))
function set_background_color!(dio::Diorama, color)
    return canvas_command(c -> set_background_color!(c, color), dio)
end
background_color(dio::Diorama) = canvas_command(c -> c.background, dio)

print_debug_timers(dio::Diorama) = print_timer(singleton(dio, TimingData).timer)
reset_debug_timers!(dio::Diorama) = reset_timer!(singleton(dio, TimingData).timer)

###########
# manipulations
# set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.camera.rotation_speed = Float32(rotation_speed)

function center_cameras(dio::Diorama)
    spat = dio[Spatial]
    cam = dio[Camera3D]
    lights = dio[PointLight]
    center = zero(Point3f0)
    e_counter = 0
    for e in @entities_in(spat && !cam && !lights)
        center += e.position
        e_counter += 1
    end
    center /= e_counter

    for e in @entities_in(spat && cam)
        current_pos  = e.position
        current_dist = norm(e.lookat - current_pos)
        # we want to keep the distance to the lookat constant
        u_forward = unitforward(current_pos, center)
        new_pos = center - current_dist * u_forward
        e[Spatial] = Spatial(new_pos, e.velocity)
        e.lookat = Vec3f0(center)
    end
end

function push_system(dio::Diorama, s::System)
    return (dio.ledger = push_system(dio.ledger, s); glimpse_call(() -> Overseer.prepare(dio)))
end

function insert_system(dio::Diorama, id::Integer, s::System)
    return (dio.ledger = insert_system(dio.ledger, id, s); glimpse_call(() -> Overseer.prepare(dio)))
end

debug_timer(dio::Diorama) = singleton(dio, TimingData).timer

function Base.empty!(dio::Diorama)
    dio_entities = dio[DioEntity]
    for e in valid_entities(dio)
        if !(e in dio_entities)
            schedule_delete!(dio.ledger, e)
        end
    end
    return delete_scheduled!(dio.ledger)
end

#TODO make a sanitize camera stuff
function center_camera!(dio::Diorama, p::Point3f0)
    camera          = singleton(dio, Camera3D)
    camera_entity   = Entity(first(dio[Camera3D].indices))
    eye             = dio[Spatial][camera_entity].position
    lookat          = camera.lookat
    shift           = p - lookat
    camera.lookat   = p
    new_eye         = eye + shift
    camera.view     = lookatmat(new_eye, p, camera.up)
    camera.projview = camera.proj * camera.view
    return dio[Spatial][camera_entity] = Spatial(dio[Spatial][camera_entity];
                                                 position = new_eye)
end

function Base.setindex!(dio::Diorama, v::T, e::Entity) where {T<:ComponentData}
    setindex!(dio.ledger, v, e)
    return update_component!(dio, T)
end

function update_component!(dio::Diorama, ::Type{T}) where {T<:ComponentData}
    uc = singleton(dio, UpdatedComponents)
    if !in(T, uc.components)
        push!(uc, T)
    end
end

function reload_shaders(dio::Diorama)
    return glimpse_call(() -> for prog in components(dio, RenderProgram)
                            ProgType = eltype(prog)
                            dio[Entity(1)] = ProgType(Program(shaders(ProgType)))
                        end)
end

function register_update(dio::Diorama, ::Type{T}) where {T<:ComponentData}
    return T ∈ singleton(dio, UpdatedComponents) ? nothing :
           push!(singleton(dio, UpdatedComponents), T)
end
