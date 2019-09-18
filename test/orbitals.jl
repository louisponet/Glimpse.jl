using Glimpse
const Gl = Glimpse
import Glimpse: RGBAf0
using GeometryTypes
using LinearAlgebra
import LinearAlgebra: norm
using ColorSchemes

cscheme = ColorScheme([RGBAf0(1.0,0.0,0.0,0.6), RGBAf0(0.0,0.0,0.0,0.6), RGBAf0(0.0,0.0,1.0,0.6)], "custom", "red black blue")
sz = [1 0;0 -1]
ψ  = p -> [p[1]*p[2], (p[1] + 1im*p[2])*p[3]/sqrt(2)] .* ℯ^-norm(p)
function densfunc(p, orb)
	ψ = orb(p)
	return convert(Float32, real(ψ'*ψ))
end

function colorfunc(p, orb, cscheme)
	ψ = orb(p)
	if norm(ψ) == 0
		return RGBAf0(0.0, 0.0, 0.0, 0.6)
	else
		c = get(cscheme, 0.5+0.5*real(ψ'*sz*ψ/(ψ'*ψ)))
		return c::RGBAf0
	end
end
grid  = Gl.Grid([Point3f0(a, b, c) for a=-3:1:3, b=-3:1:3, c=-3:1:3])

ccomp = Gl.FunctionColor(p -> colorfunc(p, ψ, cscheme))
dcomp = Gl.FunctionGeometry(p -> densfunc(p, ψ), 0.001f0)
Entity(dio, Gl.Spatial(),
                              Gl.Material(),
                              Gl.Shape(),
                              ccomp,
                              dcomp,
                              Gl.ProgramTag{Gl.PeelingProgram}(), grid)

