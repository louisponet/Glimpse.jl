import GLAbstraction: Program

struct Pipeline
    name::Symbol
    context::Context
    renderables::Array{Renderable, 1}
    passes::Array{RenderPass, 1}
    combining_program::Program
end
