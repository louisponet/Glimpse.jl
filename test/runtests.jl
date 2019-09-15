using Glimpse
const Gl = Glimpse
using Test

# write your own tests here
finalize(dio) = (Gl.ECS.prepare(dio); Gl.renderloop(dio); sleep(1); Gl.close(dio); sleep(1))
include_finalize(str) = (include(str); finalize(dio))
@testset "text" begin include_finalize("text.jl") end 
# @testset "gui_text" begin include_finalize("gui_text.jl") end 
@testset "mouse_selection" begin include_finalize("mouse_selection.jl") end 
# @testset "orbitals" begin include("orbitals.jl") end 
# @testset "screensaver" begin include_finalize("screensaver.jl") end 
@testset "oscillating_depth_peel" begin include_finalize("oscillating_depth_peel.jl") end 
@testset "instanced_depth_peel" begin include_finalize("instanced_depth_peel.jl") end 
