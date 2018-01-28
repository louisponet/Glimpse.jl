import GLAbstraction: Program, FrameBuffer

struct RenderPass
    id::Int
    name::Symbol
    program::Program
    target::FrameBuffer
    func::Function
end
