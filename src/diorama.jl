import GLAbstraction: free!
########### Initialization

ECS.manager(dio::Diorama) = dio.manager

function Diorama(extra_systems...; name = :Glimpse, kwargs...) #Defaults
	m = Manager(SystemStage(:start, [Timer()]),
                SystemStage(:setup, [PolygonMesher(),
			                         DensityMesher(),
			                         VectorMesher(),
			                         FunctionMesher(),
			                         FunctionColorizer(),
			                         AABBGenerator(),
			                         Uploader(),
			                         InstancedUploader(),
			                         TextUploader()]),
                extra_systems...,

			    SystemStage(:simulation, [Oscillator(),
                        			      Mover(),
                        			      MousePicker(),
                        			      UniformCalculator(),
                        			      CameraOperator()]),

				SystemStage(:rendering, [LineRenderer(),
				                         TextRenderer(),
			                             UniformUploader(),
			                             DefaultRenderer(),
			                             DepthPeelingRenderer(),
			                             GuiRenderer(),
			                             FinalRenderer()]),

			    SystemStage(:stop, [Resizer(), Sleeper()]))


    #assemble all rendering, canvas and camera components
    e = Entity(m, DioEntity(), Canvas(name; kwargs...), TimingData())
    c = m[Canvas][e]
	wh = size(c)
    m[e] = IOTarget(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background)
    m[e] = FullscreenVao()
    m[e] = UpdatedComponents(DataType[])
    for v in assemble_camera3d(Int32.(size(c))...)
        m[e] = v
    end

	Entity(m, DioEntity(), Spatial(position=Point3f0(200f0)),
	          PointLight(),
	          UniformColor(RGBA{Float32}(1.0)))

	t = Diorama(name, m; kwargs...)
	ECS.prepare(t)
	return t
end


# "Darken all the lights in the dio by a certain amount"
# darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
# lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

#This is kind of like a try catch command to execute only when a valid canvas is attached to the diorama
#i.e All GL calls should be inside one of these otherwise it might be bad.
function canvas_command(dio::Diorama, command::Function, catchcommand = x -> nothing)
	canvas = dio.manager[Canvas][1]
	if canvas != nothing
		command(canvas)
	else
		catchcommand(canvas)
	end
end

function expose(dio::Diorama;  kwargs...)
    if dio.loop == nothing
	    canvas_command(dio, make_current, x -> ECS.Entity(dio, Canvas(dio.name; kwargs...))) 
    end
    renderloop(dio)
    canvas_command(dio, expose)

    return dio
end

function ECS.update(dio::Diorama, init=false)
	timer = singleton(dio, TimingData).timer
	mesg = init ? "Init" : "Running"
    @timeit timer mesg for stage in system_stages(dio)
        for sys in last(stage)
            timeit(() -> update(sys, dio), timer, string(typeof(sys)))
        end
    end
end

#TODO move control over this to diorama itself
function renderloop(dio)
    dio    = dio
    ECS.prepare(dio)
    canvas_command(dio, canvas ->
	    dio.loop = @async begin
    	    try
        	    update(dio, true)

    	    	while !should_close(canvas)
    				pollevents(canvas)
    			    clear!(canvas)
    			    iofbo = singleton(dio, IOTarget)
    			    bind(iofbo)
    			    draw(iofbo)
    			    clear!(iofbo)
    			    update(dio)
    			    empty!(singleton(dio, UpdatedComponents))
    		    end
    		    close(canvas)
    			dio.loop = nothing
			catch
    		    close(canvas)
                for stage in system_stages(dio)
                    # first(stage) == :setup && continue
                    ECS.update(stage, dio)
                end
    			dio.loop = nothing
			end
		end
	)
end

function reload(dio::Diorama)
	close(dio)
	canvas_command(dio, canvas ->
		begin
			while isopen(canvas) && dio.loop != nothing
				sleep(0.01)
			end
			dio.reupload = true
		    expose(dio)
	    end
    )
end

function close(dio::Diorama)
    canvas_command(dio, canvas -> should_close!(canvas, true))
    if dio.loop === nothing
        canvas_command(dio, canvas->close(canvas))
    end
end

free!(dio::Diorama) = canvas_command(dio, c -> free!(c))

isrendering(dio::Diorama) = dio.loop != nothing

const currentdio = Base.RefValue{Diorama}()

getcurrentdio() = currentdio[]
iscurrentdio(x) = x == currentdio[]
function makecurrentdio(x)
    currentdio[] = x
end

Base.size(dio::Diorama)  = canvas_command(dio, c -> windowsize(c), x -> (0,0))
set_background_color!(dio::Diorama, color) = canvas_command(dio, c -> set_background_color!(c, color))
background_color(dio::Diorama) = canvas_command(dio, c -> c.background)

print_debug_timers(dio::Diorama) = print_timer(singleton(dio, TimingData).timer)
reset_debug_timers!(dio::Diorama) = reset_timer!(singleton(dio, TimingData).timer)

###########
# manipulations
# set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.camera.rotation_speed = Float32(rotation_speed)

function center_cameras(dio::Diorama)
	spat = component(dio, Spatial)
	cam = component(dio, Camera3D)
	lights = component(dio, PointLight)
	scene_entities = setdiff(valid_entities(spat), valid_entities(cam) ∪ valid_entities(lights))
	center = zero(Point3f0)
	e_counter = 0 
	for e in scene_entities 
		center += spat[e].position
		e_counter += 1
	end
	center /= e_counter

	for id in valid_entities(spat, cam)
		c            = cam[id]
		current_pos  = spat[id].position
		current_dist = norm(c.lookat - current_pos)
		# we want to keep the distance to the lookat constant
		u_forward    = unitforward(current_pos, center)
		new_pos      = center - current_dist * u_forward
		spat[id]     = Spatial(new_pos, spat[id].velocity)
		overwrite!(cam, Camera3D(c, new_pos, center, u_forward), id)
    end
end

push_system(dio::Diorama, s::System) =
	(dio.manager = push_system(dio.manager, s); ECS.prepare(dio))
	
insert_system(dio::Diorama, id::Integer, s::System) =
	(dio.manager = insert_system(dio.manager, id, s); ECS.prepare(dio))




