import GLAbstraction: VertexArray
import GeometryTypes: HomogenousMesh

struct Renderable{D} #D for dimensions
    id::Int
    name::Symbol
    mesh::AbstractMesh{Vec{D, GLfloat}, Face{D, GLfloat}} #probably don't need a dict for the attributes
    uniforms::Dict{Symbol, Any}
    vao::Union{VertexArray, Void}
end
