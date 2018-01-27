sing GLider
screen = Screen()
try
while isopen(screen)
    clearcanvas!(screen)
    swapbuffers(screen)
    waitevents(screen)
    println(screen.callbacks[:window_size][])
end
finally
destroy!(screen)
end
