using Glimpse
using Test

# write your own tests here
@testset "text" begin include("text.jl") end 
@testset "gui_text" begin include("gui_text.jl") end 
@testset "mouse_selection" begin include("mouse_selection.jl") end 
@testset "orbitals" begin include("orbitals.jl") end 
@testset "screensaver" begin include("screensaver.jl") end 
@testset "oscillating_depth_peel" begin include("oscillating_depth_peel.jl") end 
@testset "instanced_depth_peel" begin include("instanced_depth_peel.jl") end 
