import GLAbstraction: FrameBuffer
import GLAbstraction: textureformat_from_type_sym


defaultframebuffer(fb_size) = FrameBuffer(fb_size, DepthStencil{GLAbstraction.Float24, N0f8}, RGBA{N0f8}, Vec{2, GLushort}, RGBA{N0f8})
