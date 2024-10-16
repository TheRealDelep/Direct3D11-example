package main

import "graphics"

import d3d "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:stb/image"

get_texture_quad_draw_cmd :: proc() -> graphics.DrawCommand {
    vertex_shader, vs_blob  := graphics.compile_vertex_shader("shaders.hlsl")   
    pixel_shader, ps_blob   := graphics.compile_pixel_shader("shaders.hlsl")   

    input_layout : ^d3d.IInputLayout
    input_elem_desc := []d3d.INPUT_ELEMENT_DESC {{
        SemanticName = "POS", SemanticIndex = 0,
        Format = dxgi.FORMAT.R32G32_FLOAT,
        InputSlot = 0,
        InputSlotClass = .VERTEX_DATA,
        AlignedByteOffset = 0,
        InstanceDataStepRate = 0
    }, {
        SemanticName = "TEX", SemanticIndex = 0,
        Format = dxgi.FORMAT.R32G32_FLOAT,
        InputSlot = 0,
        InputSlotClass = .VERTEX_DATA,
        AlignedByteOffset = d3d.APPEND_ALIGNED_ELEMENT,
        InstanceDataStepRate = 0
    }}

    h_result := graphics.device->CreateInputLayout(
        &input_elem_desc[0], 
        cast(u32) len(input_elem_desc),
        vs_blob->GetBufferPointer(),
        vs_blob->GetBufferSize(),
        &input_layout
    )

    assert(h_result == 0)

    // Vertex buffer
    vertex_buffer   : ^d3d.IBuffer
    vertex_count    : u32
    stride          : u32
    offset          : u32
    
    // x, y, u, v
    vertex_data := []f32 {
        -0.5,  0.5, 0, 0,
        0.5, -0.5, 1, 1,
        -0.5, -0.5, 0, 1,
        -0.5,  0.5, 0, 0,
        0.5,  0.5, 1, 0,
        0.5, -0.5, 1, 1
    }

    stride = 4 * size_of(f32)
    vertex_count = size_of(vertex_data) / stride
    offset = 0

    vertex_buffer_desc := d3d.BUFFER_DESC {
        ByteWidth   = size_of(vertex_data),
        Usage       = .IMMUTABLE,
        BindFlags   = { .VERTEX_BUFFER }
    }

    // Sampler State
    sampler_desc := d3d.SAMPLER_DESC {
        Filter          = .MIN_MAG_MIP_POINT,
        AddressU        = .BORDER,
        AddressV        = .BORDER,
        AddressW        = .BORDER,
        BorderColor     = { 1, 1, 1, 1 },
        ComparisonFunc  = .NEVER
    }

    sampler_state : ^d3d.ISamplerState
    graphics.device->CreateSamplerState(&sampler_desc, &sampler_state)

    // Load Image
    tex_width, tex_height, tex_channel_count : u32
    tex_force_channel_count :: 4
    texture_bytes := image.load(
        "testTexture.png", 
        cast(^i32)&tex_width, cast(^i32)&tex_height, 
        cast(^i32)&tex_channel_count, tex_force_channel_count
    )
    
    assert(texture_bytes != nil)
    
    tex_bytes_per_row := 4 * tex_width

    // Create texture
    texture_desc := d3d.TEXTURE2D_DESC {
        Width       = tex_width,
        Height      = tex_height,
        MipLevels   = 1,
        ArraySize   = 1,
        Format      = dxgi.FORMAT.R8G8B8A8_UNORM_SRGB,
        SampleDesc  = { Count = 1 },
        Usage       = .IMMUTABLE,
        BindFlags   =  { .SHADER_RESOURCE }
    }

    tex_subresource_data := d3d.SUBRESOURCE_DATA {
        pSysMem     = texture_bytes,
        SysMemPitch = tex_bytes_per_row
    }

    texture : ^d3d.ITexture2D
    graphics.device->CreateTexture2D(&texture_desc, &tex_subresource_data, &texture)
    
    texture_view : ^d3d.IShaderResourceView
    graphics.device->CreateShaderResourceView(texture, nil, &texture_view) 

    free(texture_bytes)

    return graphics.DrawCommand {
        input_layout, vertex_shader, pixel_shader,
        vertex_buffer, vertex_count, stride, offset
    }
}
