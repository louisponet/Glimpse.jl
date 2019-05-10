# These are all the systems used for the general running of Dioramas

struct Sleeper <: System
	data ::SystemData

	Sleeper(dio::Diorama) = new(SystemData(dio, (), (TimingData, Canvas)))
end 

function update(sleeper::Sleeper)
	swapbuffers(singleton(sleeper, Canvas))
	sd         = singletons(sleeper)[1]
	curtime    = time()
	sleep_time = sd.preferred_fps - (curtime - sd.time)
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end

struct Resizer <: System
	data ::SystemData

	Resizer(dio::Diorama) = new(SystemData(dio, (), (Canvas, RenderTarget)))
end

function update(sys::Resizer)
	c   = singleton(sys, Canvas)
	fwh = callback_value(c, :framebuffer_size)
	resize!(c, fwh)
	for rt in singletons(sys, RenderTarget)
		resize!(rt, fwh)
	end
end
