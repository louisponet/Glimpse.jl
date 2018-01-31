@inline function sleep_pessimistic(sleep_time)
    st = convert(Float64, sleep_time) - 0.002
    start_time = time()
    while (time() - start_time) < st
        sleep(0.001) # sleep for the minimal amount of time
    end
end