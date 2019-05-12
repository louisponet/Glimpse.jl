import GLAbstraction: free!

########### Initialization
#TODO, make it so args and kwargs get all passed around to pipelines and screens etc
function Diorama(name::Symbol = :Glimpse; kwargs...) #Defaults
	c                  = Canvas(name; kwargs...)
	wh                 = size(c)
	io_fbo             = RenderTarget{IOTarget}(GLA.FrameBuffer(wh, (RGBAf0, GLA.Depth{Float32}), true), c.background)
	# text_pass          = text_pass()
	fullscreenvao      = FullscreenVao()
    def_prog           = RenderProgram{DefaultProgram}(GLA.Program(default_shaders()))
    def_inst_prog      = RenderProgram{DefaultInstancedProgram}(GLA.Program(default_instanced_shaders()))
    peel_prog          = RenderProgram{PeelingProgram}(GLA.Program(peeling_shaders()))
    peel_inst_prog     = RenderProgram{PeelingInstancedProgram}(GLA.Program(peeling_instanced_shaders()))
    line_prog          = RenderProgram{LineProgram}(GLA.Program(line_shaders()))
    text_prog          = RenderProgram{TextProgram}(GLA.Program(text_shaders()))
    updated_components = UpdatedComponents(DataType[])
    font_storage       = FontStorage()

	timing = TimingData(time(),0.0, 0, 1/60, false)
	dio = Diorama(name, Entity[], AbstractComponent[], [timing, io_fbo, c, fullscreenvao, def_prog, def_inst_prog, peel_prog, peel_inst_prog, updated_components, line_prog, text_prog, font_storage], System[])
    add_component!.((dio,),[PolygonGeometry,
    						FileGeometry,
    						FunctionGeometry,
    						DensityGeometry,
    						VectorGeometry,
    						FunctionColor,
    						DensityColor,
    						BufferColor,
    						Mesh,
		                    Material,
		                    Spatial,
		                    Shape,
		                    UniformColor,
		                    PointLight,
		                    Camera3D,
		                    Dynamic,
		                    ModelMat,
		                    Line,
		                    Text,
		                    Selectable,
		                    AABB,
		                    ProgramTag{DefaultProgram},
		                    ProgramTag{DefaultInstancedProgram},
		                    ProgramTag{PeelingProgram},
		                    ProgramTag{PeelingInstancedProgram},
		                    ProgramTag{LineProgram},
		                    Vao{DefaultProgram},
		                    Vao{PeelingProgram},
		                    Vao{LineProgram},
		                    Vao{TextProgram}])
    add_shared_component!.((dio,), [PolygonGeometry,
    							    AABB,
    								FileGeometry,
    							    Mesh,
							        Vao{DefaultInstancedProgram},
    							    Vao{PeelingInstancedProgram},
    							    Grid])

	add_system!.((dio,),[Timer(dio),
						 Resizer(dio),
                         Mesher(dio),
                         AABBGenerator(dio),
                         UniformCalculator(dio),
                         MousePicker(dio),
			             DefaultUploader(dio),
			             DefaultInstancedUploader(dio),
			             LinesUploader(dio),
			             PeelingUploader(dio),
			             PeelingInstancedUploader(dio),
                         UniformUploader{DefaultInstancedProgram}(dio),
                         UniformUploader{PeelingInstancedProgram}(dio),
                         TextUploader(dio),
			             Camera(dio),
			             DefaultRenderer(dio),
			             DepthPeelingRenderer(dio),
			             TextRenderer(dio),
			             FinalRenderer(dio),
			             Sleeper(dio)])


	add_entity!(dio, separate = [Spatial(position=Point3f0(200f0), velocity=zero(Vec3f0)), PointLight(), UniformColor(RGBA{Float32}(1.0))])
	add_entity!(dio, separate = [assemble_camera3d(size(dio)...)...])
	return dio
end


# "Darken all the lights in the dio by a certain amount"
# darken!(dio::Diorama, percentage)  = darken!.(dio.lights, percentage)
# lighten!(dio::Diorama, percentage) = lighten!.(dio.lights, percentage)

#This is kind of like a try catch command to execute only when a valid canvas is attached to the diorama
#i.e All GL calls should be inside one of these otherwise it might be bad.
function canvas_command(dio::Diorama, command::Function, catchcommand = x -> nothing)
	canvas = singleton(dio, Canvas)
	if canvas != nothing
		command(canvas)
	else
		catchcommand(canvas)
	end
end

function expose(dio::Diorama;  kwargs...)
    if dio.loop == nothing
	    canvas_command(dio, make_current, x -> add_singleton!(dio, Canvas(dio.name; kwargs...))) 
    end
    return dio
end

#TODO move control over this to diorama itself
function renderloop(dio)
    dio    = dio
    canvas_command(dio, canvas ->
	    begin
	    	while !should_close(canvas)
			    clear!(canvas)
			    iofbo = singleton(dio, RenderTarget{IOTarget})
			    bind(iofbo)
			    draw(iofbo)
			    clear!(iofbo)
			    empty!(singleton(dio, UpdatedComponents))
		        for sys in engaged_systems(dio)
			        update(sys)
		        end
		    end
		    close(dio)
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
close(dio::Diorama) = canvas_command(dio, c -> (close(c); should_close!(c, false)))
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


# __/\\\\\\\\\\\\\\\________/\\\\\\\\\_____/\\\\\\\\\\\___        
#  _\/\\\///////////______/\\\////////____/\\\/////////\\\_       
#   _\/\\\_______________/\\\/____________\//\\\______\///__      
#    _\/\\\\\\\\\\\______/\\\_______________\////\\\_________     
#     _\/\\\///////______\/\\\__________________\////\\\______    
#      _\/\\\_____________\//\\\____________________\////\\\___   
#       _\/\\\______________\///\\\___________/\\\______\//\\\__  
#        _\/\\\\\\\\\\\\\\\____\////\\\\\\\\\_\///\\\\\\\\\\\/___ 
#         _\///////////////________\/////////____\///////////_____

function Base.empty!(dio::Diorama)
	for component in dio.components
		empty!(component)
	end
	empty!(dio.entities)
end

#TODO: change such that there are no components until needed?
function component(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	for c in components(dio)
		if eltype(c) <: T && isa(c, Component)
			return c
		end
	end
	for c in components(dio)
		if T <: eltype(c) && isa(c, Component)
			return c
		end
	end
end

function shared_component(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	for c in components(dio)
		if eltype(c) <: T && isa(c, SharedComponent)
			return c
		end
	end
	for c in components(dio)
		if T <: eltype(c) && isa(c, SharedComponent)
			return c
		end
	end
end

components(dio::Diorama) = dio.components

function components(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	compids = findall(x -> eltype(x) <: T, dio.components)
	@assert compids != nothing "Component $T was not found, please add it first"
	return dio.components[compids]
end

function singletons(dio::Diorama, ::Type{T}) where {T <: Singleton}
	singlids = findall(x -> typeof(x) <: T, dio.singletons)
	@assert singlids != nothing "No singleton of type $T was not found, please add it first"
	return dio.singletons[singlids]
end

ncomponents(dio::Diorama) = length(dio.components)

singleton(dio::Diorama, ::Type{T}) where {T <: Singleton} = getfirst(x -> isa(x, T), dio.singletons)

function add_component_to_systems(dio, comp::AbstractComponent{T}) where T
	for sys in dio.systems
		for rc in sys.data.requested_components
			if T <: rc
				push!(sys.data.components, comp)
				return
			end
		end
	end
end


function add_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	comp = Component(ncomponents(dio)+1, T)
	push!(dio.components, comp)
	add_component_to_systems(dio, comp)
end
	
function add_shared_component!(dio::Diorama, ::Type{T}) where {T <: ComponentData}
	comp = SharedComponent(ncomponents(dio)+1, T)
	push!(dio.components, comp)
	add_component_to_systems(dio, comp)
end

system(dio::Diorama, ::Type{T}) where {T <: System} =
	getfirst(x -> isa(x, T), dio.systems)

add_system!(dio::Diorama, sys::System) = push!(dio.systems, sys)

insert_system!(dio::Diorama, i::Int, sys::System) = insert!(dio.systems, i, sys)

function insert_system_after!(dio::Diorama, ::Type{T}, sys::System) where {T<:System}
	id = findfirst(x -> isa(x, T), dio.systems)
	if id != nothing
		insert!(dio.systems, id + 1, sys)
	end
end

function insert_system_before!(dio::Diorama, ::Type{T}, sys::System) where {T<:System}
	id = findfirst(x -> isa(x, T), dio.systems)
	if id != nothing
		insert!(dio.systems, id - 1, sys)
	end
end

function remove_system!(dio::Diorama, ::Type{T}) where {T <: System}
	sysids = findall(x -> isa(x, T), dio.systems)
	deleteat!(dio.systems, sysids)
end
	

#TODO handle freeing and reusing stuff
#TODO MAKE SURE THAT ALWAYS ALL ENTITIES WITH CERTAIN COMPONENTS THAT SYSTEMS CARE ABOUT IN UNISON ARE SORTED 
function add_to_components!(id, datas, components)
	for (data, comp) in zip(datas, components)
		comp[id] = data
	end
end

function add_entity!(dio::Diorama; separate::Vector{<:ComponentData}=ComponentData[], shared::Vector{<: ComponentData}=ComponentData[])
	entity_id  = length(dio.entities) + 1

	names      = typeof.(separate)
	components = component.((dio, ), names)
	shared_names      = typeof.(shared)
	shared_components = shared_component.((dio, ), shared_names)
	@assert !(any(components .== nothing) || any(shared_components .== nothing)) "One or more components in $(names[findall(isequal(nothing), components)]) is not present in the dio yet. TODO add this automatically"
    add_to_components!(entity_id, separate, components)
    add_to_components!(entity_id, shared, shared_components)
	
	push!(dio.entities, Entity(entity_id))
	return entity_id
end

function set_entity_component!(dio::Diorama, entity_id::Int, componentdatas::ComponentData...)
	entity = getfirst(x->x.id == entity_id, dio.entities)
	if entity == nothing
		error("entity id $entity_id doesn't exist")
	end

	for data in componentdatas
		component(dio, typeof(data)).data[entity_id] = data
	end
end



###########
# manipulations
# set_rotation_speed!(dio::Diorama, rotation_speed::Number) = dio.camera.rotation_speed = Float32(rotation_speed)

function component_ids(dio::Diorama, ComponentTypes)
	diocomps = components(dio)
	ids      = zeros(Int, length(ComponentTypes))
	for (ic, ct) in enumerate(ComponentTypes)
		for c in diocomps
			if eltype(c) == ct
				ids[ic] = c.id
			end
		end
	end
	return ids
end

function get_components(dio::Diorama, component_ids::Vector{Int})
	ncomps   = length(component_ids)
	diocomps = components(dio)
	comps    = Vector{Component}(undef, ncomps)
	for (ic, cid) in enumerate(component_ids)
		for c in diocomps
			if c.id == cid
				comps[ic] = c
			end
		end
	end
	return comps
end

function get_components(dio::Diorama, ComponentTypes::Type{<:ComponentData}...)
	ncomps   = length(ComponentTypes)
	diocomps = components(dio)
	comps    = Vector{Component}(undef, ncomps)
	for (ic, ct) in enumerate(ComponentTypes)
		for c in diocomps
			if eltype(c) == ct
				comps[ic] = c
			end
		end
	end
	return comps
end
#maybe this should be splitted into a couple of systems

component_types(sys::System) = eltype.(sys.components)
component_ids(sys::System)   = [c.id for c in sys.components]
component_id(sys::System, ::Type{DT}) where {DT<:ComponentData} = findfirst(isequal(DT), component_types(sys))

function has_components(e::Entity, components::Vector{<:Component})
	c = 0
	for ct in components
		if has_index(ct.data, e.id)
			c += 1
		end
	end
	return c == length(component_ids)
end

engaged_systems(dio) = filter(x -> isengaged(x), dio.systems)

function update_system_indices!(dio::Diorama)
	for j = 1:2
		for i=1:length(dio.systems) - 1
			update(dio.systems[i])
			update_indices!(dio.systems[i+1])
		end
	end
	# for sys in dio.systems
	# 	if isempty(indices(sys)) || all(isempty.(indices(sys)))
	# 		@show "ping"
	# 		disengage!(sys)
	# 	end
	# end
end


# function reupload(::Diorama)
# 	renderables = fi(x -> x.should_upload, dio.renderables)
# 	for rp in dio.pipeline
# 		upload(filter(x->has_pass(x, rp), renderables), rp)
# 	end
# end
