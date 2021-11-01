using Glimpse
const Gl = Glimpse
using Test

dio = Gl.Diorama(; backgroud = Gl.RGBAf0(0.0, 0.0, 0.0, 1.0))
# write your own tests here
finalize(dio) = (Gl.Overseer.prepare(dio); Gl.Overseer.update_systems(dio.ledger))
include_finalize(str) = (include(str); finalize(dio))
@testset "text" begin
    include_finalize("text.jl")
end
@testset "gui_text" begin
    include_finalize("gui_text.jl")
end
@testset "mouse_selection" begin
    include_finalize("mouse_selection.jl")
end
@testset "orbitals" begin
    include("orbitals.jl")
end
@testset "screensaver" begin
    include_finalize("screensaver.jl")
end
@testset "oscillating_depth_peel" begin
    include_finalize("oscillating_depth_peel.jl")
end
@testset "instanced_depth_peel" begin
    include_finalize("instanced_depth_peel.jl")
end
