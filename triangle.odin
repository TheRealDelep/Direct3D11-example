package main

import d3d "vendor:directx/d3d11"
import "vendor:directx/dxgi"

import "graphics"

get_triangle_draw_cmd :: proc() -> graphics.DrawCommand {
    vertex_shader, vs_blob   := graphics.compile_vertex_shader("simp_shaders.hlsl")
    pixel_shader, ps_blob    := graphics.compile_pixel_shader("simp_shaders.hlsl")

    input_layout : ^d3d.IInputLayout

    input_elem_desc := []d3d.INPUT_ELEMENT_DESC {{ 
        SemanticName = "pos", SemanticIndex = 0, 
        Format = dxgi.FORMAT.R32G32_FLOAT,
        InputSlot = 0, InputSlotClass = .VERTEX_DATA,
        AlignedByteOffset = 0, 
        InstanceDataStepRate = 0
    }, { 
        SemanticName = "col", SemanticIndex = 0, 
        Format = dxgi.FORMAT.R32G32B32A32_FLOAT,
        InputSlot = 0, InputSlotClass = .VERTEX_DATA,
        AlignedByteOffset = d3d.APPEND_ALIGNED_ELEMENT, 
        InstanceDataStepRate = 0
    }}

    h_result := graphics.device->CreateInputLayout(
        &input_elem_desc[0], 
        2, 
        vs_blob->GetBufferPointer(), 
        vs_blob->GetBufferSize(), 
        &input_layout
    )

    assert(h_result == 0)

    vertex_buffer   : ^d3d.IBuffer
    vertex_count    : u32
    stride          : u32
    offset          : u32

    // x, y, r, g, b, a
    vertex_data := []f32 {
        0, .5, 1, 0, 0, 1,
        .5, -.5, 0, 1, 0, 1,
        -.5, -.5, 0, 0, 1, 1,
    }

    stride = 6 * size_of(f32) 
    data_size := size_of(f32) * u32(len(vertex_data))
    vertex_count = data_size / stride
    offset = 0

    vertex_buffer_desc := d3d.BUFFER_DESC {
        ByteWidth = data_size,
        Usage = .IMMUTABLE,
        BindFlags = { .VERTEX_BUFFER }
    }

    vertex_subresource_data := d3d.SUBRESOURCE_DATA {}
    vertex_subresource_data.pSysMem = raw_data(vertex_data)

    h_result = graphics.device->CreateBuffer(&vertex_buffer_desc, &vertex_subresource_data, &vertex_buffer)
    assert(h_result == 0)

    return graphics.DrawCommand {
        input_layout, vertex_shader, pixel_shader,
        vertex_buffer, nil, nil, vertex_count,
        stride, offset
    }
}
