package graphics

import "core:fmt"
import "core:strings"
import "core:sys/windows"

import d3d "vendor:directx/d3d11"
import d3d_cmp "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

import "../window"

bg_color := [4]f32 {.15, .15, .17, 1}

device      : ^d3d.IDevice
device_ctx  : ^d3d.IDeviceContext

swap_chain          : ^dxgi.ISwapChain1
frame_buffer_view   : ^d3d.IRenderTargetView

draw_command : DrawCommand

init :: proc() {
    h_result    : d3d.HRESULT
    base_device      : ^d3d.IDevice
    base_device_ctx  : ^d3d.IDeviceContext

	feature_levels := [?]d3d.FEATURE_LEVEL{ ._11_0, ._11_1 }

    h_result = d3d.CreateDevice(
        pAdapter = nil,
        DriverType = .HARDWARE, 
        Software = nil,
        Flags = { .BGRA_SUPPORT },
        pFeatureLevels = &feature_levels[0],
        FeatureLevels = len(feature_levels),
        SDKVersion = d3d.SDK_VERSION,
        ppDevice = &base_device,
        pFeatureLevel = nil,
        ppImmediateContext = &base_device_ctx
    )
    assert(h_result == 0)
        
    h_result = base_device->QueryInterface(d3d.IDevice_UUID, (^rawptr)(&device))
    assert(h_result == 0)
    base_device->Release()

    h_result = base_device_ctx->QueryInterface(d3d.IDeviceContext_UUID, (^rawptr)(&device_ctx))
    assert(h_result == 0)
    base_device_ctx->Release()

    // debug : ^d3d.IDebug
    // device->QueryInterface(d3d.IDebug_UUID, (^rawptr)(&debug))
    // if (debug != nil) {
    //     info_queue : ^d3d.IInfoQueue
    //     
    //     h_result = debug->QueryInterface(d3d.IInfoQueue_UUID, (^rawptr)(&info_queue))
    //     assert(h_result == 0)

    //     info_queue->SetBreakOnSeverity(.CORRUPTION, true)
    //     info_queue->SetBreakOnSeverity(.ERROR, true)
    //     info_queue->Release()
    // }

    factory : ^dxgi.IFactory2
    dxgi_device : ^dxgi.IDevice
    h_result = device->QueryInterface(dxgi.IDevice_UUID, (^rawptr)(&dxgi_device))
    assert(h_result == 0)

    adapter : ^dxgi.IAdapter
    h_result = dxgi_device->GetAdapter(&adapter)
    assert(h_result == 0)
    dxgi_device->Release()

    adapter_desc : dxgi.ADAPTER_DESC 
    adapter->GetDesc(&adapter_desc)
    assert(h_result == 0)
    
    builder := strings.builder_make_none()
    
    h_result = adapter->GetParent(dxgi.IFactory2_UUID, (^rawptr)(&factory))
    assert(h_result == 0)
    adapter->Release()
        
    swap_chain_desc := dxgi.SWAP_CHAIN_DESC1 {
        Width       = 800,
        Height      = 600,
        Format      = .R8G8B8A8_UNORM,
        Stereo      = false,
        SampleDesc  = { Count = 1, Quality = 0 },
        BufferUsage =  { .RENDER_TARGET_OUTPUT },
        BufferCount = 2,
        Scaling     = .NONE,
        SwapEffect  = .FLIP_SEQUENTIAL,
        AlphaMode   = .UNSPECIFIED,
        Flags       = { },
    }

    h_result = factory->CreateSwapChainForHwnd(
        pDevice = device, 
        hWnd = window.native_handle, 
        pDesc = &swap_chain_desc,
        pFullscreenDesc = nil,
        pRestrictToOutput = nil,
        ppSwapChain = &swap_chain
    )

    assert(h_result == 0)
    factory->Release()

    frame_buffer_view : ^d3d.IRenderTargetView
    frame_buffer : ^d3d.ITexture2D
    h_result = swap_chain->GetBuffer(0, d3d.ITexture2D_UUID, (^rawptr)(&frame_buffer))
    assert(h_result == 0) 

    h_result = device->CreateRenderTargetView(frame_buffer, nil, &frame_buffer_view)
    assert(h_result == 0)
    frame_buffer->Release()
}

compile_vertex_shader :: proc(file_name: string) -> (^d3d.IVertexShader, ^d3d.IBlob) {
    vertex_shader : ^d3d.IVertexShader
    blob : ^d3d.IBlob
    shader_compiler_errors_blob : ^d3d.IBlob

    h_result := d3d_cmp.CompileFromFile(
        pFileName       = windows.utf8_to_wstring(file_name),
        pDefines        = nil,
        pInclude        = nil,
        pEntrypoint     = "vs_main",
        pTarget         = "vs_5_0",
        Flags1          = {},
        Flags2          = {},
        ppCode          = &blob,
        ppErrorMsgs     = &shader_compiler_errors_blob
    )
    assert(h_result == 0)

    h_result = device->CreateVertexShader(
        blob->GetBufferPointer(), 
        blob->GetBufferSize(), 
        nil, 
        &vertex_shader
    )
    assert(h_result == 0)

    shader_compiler_errors_blob->Release()
    return vertex_shader, blob
}

compile_pixel_shader :: proc(file_name : string) -> (^d3d.IPixelShader, ^d3d.IBlob) {
    pixel_shader : ^d3d.IPixelShader
    blob : ^d3d.IBlob
    shader_compiler_errors_blob : ^d3d.IBlob

    h_result := d3d_cmp.CompileFromFile(
        pFileName       = windows.utf8_to_wstring(file_name),
        pDefines        = nil,
        pInclude        = nil,
        pEntrypoint     = "ps_main",
        pTarget         = "ps_5_0",
        Flags1          = {},
        Flags2          = {},
        ppCode          = &blob,
        ppErrorMsgs     = &shader_compiler_errors_blob
    )

    assert(h_result == 0)

    h_result = device->CreatePixelShader(
        blob->GetBufferPointer(), 
        blob->GetBufferSize(), 
        nil, 
        &pixel_shader
    )

    assert(h_result == 0)
    return pixel_shader, blob
}

render :: proc() {
    device_ctx->ClearRenderTargetView(frame_buffer_view, &bg_color)

    win_rect : windows.RECT
    windows.GetClientRect(window.native_handle, &win_rect)
    viewport := d3d.VIEWPORT {
        0, 0, 
        f32(win_rect.right - win_rect.left), f32(win_rect.bottom - win_rect.top),
        0, 1
    }

    device_ctx->RSSetViewports(1, &viewport)

    device_ctx->IASetPrimitiveTopology(.TRIANGLELIST)
    device_ctx->IASetInputLayout(draw_command.input_layout)

    device_ctx->VSSetShader(draw_command.vertex_shader, nil, 0)
    device_ctx->PSSetShader(draw_command.pixel_shader, nil, 0)

    device_ctx->IASetVertexBuffers(0, 1, &draw_command.vertex_buffer, draw_command.strides, draw_command.offsets)
    device_ctx->OMSetRenderTargets(1, &frame_buffer_view, nil)

    device_ctx->Draw(draw_command.vertex_count, 0)

    swap_chain->Present(1, {})
}

DrawCommand :: struct {
    input_layout    : ^d3d.IInputLayout,
    vertex_shader   : ^d3d.IVertexShader,
    pixel_shader    : ^d3d.IPixelShader,
    vertex_buffer   : ^d3d.IBuffer,
    vertex_count    : u32,
    strides         : ^u32,
    offsets         : ^u32
}