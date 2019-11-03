# These are all the systems used for the general running of Dioramas
struct Timer <: System end

Overseer.requested_components(::Timer) = (TimingData,)

function Overseer.update(::Timer, m::AbstractLedger)
	for t in m[TimingData]
		nt = time()
		t.dtime = t.reversed ? - nt + t.time : nt - t.time
		t.time    = nt
		t.frames += 1
	end
end

struct Sleeper <: System end
Overseer.requested_components(::Sleeper) = (TimingData, Canvas)

function Overseer.update(::Sleeper, m::AbstractLedger)
	sd = m[TimingData]
	@timeit sd[1].timer "swapping" swapbuffers(m[Canvas][1])
	curtime    = time()
	dt = (curtime - sd[1].time)
	sleep_time = 1/sd[1].preferred_fps - dt
    st         = sleep_time - 0.002
    while (time() - curtime) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
	curtime    = time()
	dt = (curtime - sd[1].time)
end

struct Resizer <: System end
Overseer.requested_components(::Resizer) = (Canvas, IOTarget)

function Overseer.update(::Resizer, m::AbstractLedger)
	c = singleton(m, Canvas)
    iofbo = singleton(m, IOTarget)	

	fwh = c.framebuffer_size
	resize!(c, fwh)
	for c in components(m)
		if eltype(c) <: RenderTarget
			for rt in c
				resize!(rt, fwh)
			end
		end
	end
    bind(iofbo)
    draw(iofbo)
    clear!(iofbo)
end

