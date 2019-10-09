import GLAbstraction: free!
import PStdLib.ECS: AbstractComponent, push_system, insert_system
########### Initialization

ECS.manager(dio::Diorama) = dio.manager

function Diorama(extra_systems...; name = :Glimpse, kwargs...) #Defaults
	c                  = Canvas(name; kwargs...)
	wh                 = size(c)

	timing = TimingData(time(),0.0, 0, 60, false)
	m = Manager(Timer(), extra_systems...,
			    PolygonMesher(),
			    DensityMesher(),
			    VectorMesher(),
			    FunctionMesher(),
			    FunctionColorizer(),
			    Oscillator(),
			    AABBGenerator(),
			    MousePicker(),
			    UniformCalculator(),
			    Mover(),
			    ProgramTagger(),
			    DefaultUploader(),
			    InstancedDefaultUploader(),
			    LineUploader(),
				LineRenderer(),
				TextUploader(),
				TextRenderer(),
			    PeelingUploader(),
			    InstancedPeelingUploader(),
			    UniformUploader{InstancedDefaultProgram}(),
			    UniformUploader{InstancedPeelingProgram}(),
			    CameraOperator(),
			    DefaultRenderer(),
			    InstancedDefaultRenderer(),
			    DepthPeelingRenderer(),
			    InstancedDepthPeelingRenderer(),
			    GuiRenderer(),
			    FinalRenderer(),
			    Resizer(),
			    Sleeper())

	for v in (RenderTarget{IOTarget}(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background), FullscreenVao(), UpdatedComponents(DataType[]))
		e = Entity(m)
		comp_T = typeof(v)
		m[comp_T, e] = v
	end
	Entity(m, c)
	Entity(m, Spatial(position=Point3f0(200f0), velocity=zero(Vec3f0)),
	            PointLight(),
	            UniformColor(RGBA{Float32}(1.0)))

	Entity(m, assemble_camera3d(Int32.(size(c))...)...)
	Entity(m, timing)
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
    return dio
end


#TODO move control over this to diorama itself
function renderloop(dio)
    dio    = dio
    ECS.prepare(dio)
    canvas_command(dio, canvas ->
	    dio.loop = @async begin
	    	while !should_close(canvas)
				pollevents(canvas)
			    clear!(canvas)
			    iofbo = dio[RenderTarget{IOTarget}][1]
			    bind(iofbo)
			    draw(iofbo)
			    clear!(iofbo)
			    empty!(dio[UpdatedComponents][1])
			    ECS.update_systems(dio.manager)
		    end
		    close(canvas)
			dio.loop = nothing
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




