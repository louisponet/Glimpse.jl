#%%
using Glimpse
const Gl = Glimpse
using GeometryTypes
using LinearAlgebra
import LinearAlgebra: norm
using GSL
using ColorSchemes
a0=1; #for convenience, or 5.2917721092(17)×10−11 m

# The unitless radial coordinate
ρ(r,n)=2r/(n*a0);

#The θ dependence
function Pmlh(m::Int,l::Int,θ::Real)
    return (-1.0)^m *sf_legendre_Plm(l,m,cos(θ));
end

#The θ and ϕ dependence
function Yml(m::Int,l::Int,θ::Real,ϕ::Real)
    return  (-1.0)^m*sf_legendre_Plm(l,abs(m),cos(θ))*ℯ^(im*m*ϕ)
end

#The Radial dependence
function R(n::Int,l::Int,ρ::Real)
    if isapprox(ρ,0)
        ρ=.001
    end
     return sf_laguerre_n(n-l-1,2*l+1,ρ)*ℯ^(-ρ/2)*ρ^l
end

#A normalization: This is dependent on the choice of polynomial representation
function norm(n::Int,l::Int)
    return sqrt((2/n)^3 * factorial(n-l-1)/(2n*factorial(n+l)))
end

#Generates an Orbital Funtion of (r,θ,ϕ) for a specificied n,l,m.
function Orbital(n::Int,l::Int,m::Int)
    if (l>n)    # we make sure l and m are within proper bounds
        throw(DomainError())
    end
    if abs(m)>l
       throw(DomainError())
    end
    psi(ρ,θ,ϕ)=norm(n, l)*R(n,l,ρ)*Yml(m,l,θ,ϕ);
    return psi
end

#We will calculate is spherical coordinates, but plot in cartesian, so we need this array conversion
function SphtoCart(rθϕ::Array,θ::Array,ϕ::Array)
    x=r.*sin.(θ).*cos.(ϕ);
    y=r.*sin.(θ).*sin.(ϕ);
    z=r.*cos.(θ);
    return x,y,z;
end

function CarttoSph(x::Array,y::Array,z::Array)
    r=sqrt.(x.^2+y.^2+z.^2);
    θ=acos.(z./r);
    ϕ=atan.(y./x);
    return r,θ,ϕ;
end
testdiorama = Diorama(:Glimpse, Screen(:default, (1260, 720)));
testdiorama.components[1].data.start_ids

#%%
r=-100:0.5:100
x=collect(r);
y=collect(r);
z=collect(r);
N=length(x);
xa=repeat(x,outer=[1,N,N])
ya=repeat(reshape(y, 1, N, 1),outer=[N,1,N])
za=repeat(reshape(z,1,1,N),outer=[N,N,1]);
println("created x,y,z")

rr,θ, ϕ=CarttoSph(xa,ya,za);
println("created r,θ,ϕ")

Ψ=Orbital(10,9,4)
Ψp=Orbital(3,1,0)
Ψv = zeros(Float32,N,N,N);
ϕv = zeros(Float32,N,N,N);
for nn in 1:N
    for jj in 1:N
        for kk in 1:N
            val=Ψ(ρ(rr[nn,jj,kk],2),θ[nn,jj,kk],ϕ[nn,jj,kk]);
            #val+=Ψp(ρ(r[nn,jj,kk],2),θ[nn,jj,kk],ϕ[nn,jj,kk]);
            Ψv[nn,jj,kk]=convert(Float32,abs(val));
            ϕv[nn,jj,kk]=Base.isnan(angle(val)) ? 0.0f0 : convert(Float32,angle(val));
        end
    end
end
mid=round(Int,(N-1)/2+1);
Ψv[mid,mid,:]=Ψv[mid+1,mid+1,:]; # the one at the center diverges
Ψv=(Ψv.-minimum(Ψv))./(maximum(Ψv)-minimum(Ψv) )
include("meshing.jl")

points = [Point3f0(x, y, z) for x in r, y in r, z in r]

verts, ids = marching_cubes(Ψv, points, 0.3)
faces = [Face{3,Gl.GLint}(i,i+1,i+2) for i=1:3:length(verts)]
minscal = minimum(ϕv)
maxscal = maximum(ϕv)
cscheme = ColorSchemes.phase
colors = [RGBA{Float32}(get(cscheme, ϕv[id...], (minscal, maxscal)),0.6f0) for id in ids]
begin
	Gl.close(testdiorama)
	empty!(testdiorama)
	Gl.new_entity!(testdiorama,
		           Gl.Spatial(Point3f0(0.0), zero(Vec3f0)),
		           Gl.Geometry(Gl.AttributeMesh(verts, faces, normals(verts,faces),
		                                        color=colors)),
		           Gl.Render{Gl.DepthPeelingPass}(false, true, Gl.VertexArray()),
		           Gl.Material(0.8f0, 0.8f0, rand(RGBA{Float32})),
		           Gl.Shape(0.1f0))

	Gl.new_entity!(testdiorama, Gl.PointLight(Point3f0(20.0), 0.5f0, 0.5f0, 0.5f0, RGBA{Float32}(1.0))) 
	Gl.new_entity!(testdiorama, Gl.Camera3D())
	sleep(0.01)
	Gl.expose(testdiorama)
end
#%%         
