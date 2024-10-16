package main

import "core:fmt"
import "core:strings"
import "core:sys/windows"

import sdl "vendor:sdl2"
import d3d "vendor:directx/d3d11"
import d3d_comp "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

window_size := [2]i32 {800, 600}

main :: proc() {
    // Sdl initialization
    sdl.Init({ .VIDEO, .EVENTS })
    defer sdl.Quit()

    sdl.SetHintWithPriority(sdl.HINT_RENDER_DRIVER, "direct3d11", .OVERRIDE)

    window := sdl.CreateWindow(
        "D3D Test", 
        sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
        window_size.x, window_size.y, 
        { }
    )
    defer sdl.DestroyWindow(window)

    window_system_info: sdl.SysWMinfo
    sdl.GetVersion(&window_system_info.version)
    sdl.GetWindowWMInfo(window, &window_system_info)
    assert(window_system_info.subsystem == .WINDOWS)

    native_window := dxgi.HWND(window_system_info.info.win.window)

    // D3D INITIALIZATION 
    h_result    : d3d.HRESULT

    device      : ^d3d.IDevice
    device_ctx  : ^d3d.IDeviceContext
    
    // base device initialization
    {
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

        fmt.println(h_result) 
        assert(h_result == 0)
        
        h_result := base_device->QueryInterface(d3d.IDevice_UUID, (^rawptr)(&device))
        assert(h_result == 0)
        base_device->Release()

        h_result = base_device_ctx->QueryInterface(d3d.IDeviceContext_UUID, (^rawptr)(&device_ctx))
        assert(h_result == 0)
        base_device_ctx->Release()
    }

    // Debug initialization
    debug : ^d3d.IDebug
    
    device->QueryInterface(d3d.IDebug_UUID, (^rawptr)(&debug))
    if (debug != nil) {
        info_queue : ^d3d.IInfoQueue
        
        h_result = debug->QueryInterface(d3d.IInfoQueue_UUID, (^rawptr)(&info_queue))
        assert(h_result == 0)

        info_queue->SetBreakOnSeverity(.CORRUPTION, true)
        info_queue->SetBreakOnSeverity(.ERROR, true)
        info_queue->Release()
    }

    // SwapChain Initialization
    swap_chain : ^dxgi.ISwapChain1
    {
        factory : ^dxgi.IFactory2
        {
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
        }
        
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
            hWnd = native_window, 
            pDesc = &swap_chain_desc,
            pFullscreenDesc = nil,
            pRestrictToOutput = nil,
            ppSwapChain = &swap_chain
        )
        fmt.println(h_result)
        assert(h_result == 0)
        factory->Release()
    }

    // Frame buffer render target
    frame_buffer_view : ^d3d.IRenderTargetView
    {
        frame_buffer : ^d3d.ITexture2D
        h_result = swap_chain->GetBuffer(0, d3d.ITexture2D_UUID, (^rawptr)(&frame_buffer))
        assert(h_result == 0) 

        h_result = device->CreateRenderTargetView(frame_buffer, nil, &frame_buffer_view)
        assert(h_result == 0)
        frame_buffer->Release()
    }

    // Vertex Shader
    vertex_shader : ^d3d.IVertexShader
    vs_blob : ^d3d.IBlob
    {
        shader_compiler_errors_blob : ^d3d.IBlob

        h_result = d3d_comp.CompileFromFile(
            pFileName       = windows.utf8_to_wstring("shaders.hlsl"),
            pDefines        = nil,
            pInclude        = nil,
            pEntrypoint     = "vs_main",
            pTarget         = "vs_5_0",
            Flags1          = {},
            Flags2          = {},
            ppCode          = &vs_blob,
            ppErrorMsgs     = &shader_compiler_errors_blob
        )

        assert(h_result == 0)

        h_result = device->CreateVertexShader(
            vs_blob->GetBufferPointer(), 
            vs_blob->GetBufferSize(), 
            nil, 
            &vertex_shader
        )

        assert(h_result == 0)
    }

    pixel_shader : ^d3d.IPixelShader
    {
        ps_blob : ^d3d.IBlob
        shader_compiler_errors_blob : ^d3d.IBlob

        h_result = d3d_comp.CompileFromFile(
            pFileName       = windows.utf8_to_wstring("shaders.hlsl"),
            pDefines        = nil,
            pInclude        = nil,
            pEntrypoint     = "ps_main",
            pTarget         = "ps_5_0",
            Flags1          = {},
            Flags2          = {},
            ppCode          = &ps_blob,
            ppErrorMsgs     = &shader_compiler_errors_blob
        )

        assert(h_result == 0)

        h_result = device->CreatePixelShader(
            ps_blob->GetBufferPointer(), 
            ps_blob->GetBufferSize(), 
            nil, 
            &pixel_shader
        )

        assert(h_result == 0)
    }

    input_layout : ^d3d.IInputLayout
    {
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

        h_result = device->CreateInputLayout(
            &input_elem_desc[0], 
            2, 
            vs_blob->GetBufferPointer(), 
            vs_blob->GetBufferSize(), 
            &input_layout
        )
    }

    vertex_buffer   : ^d3d.IBuffer
    vertex_count    : u32
    stride          : u32
    offset          : u32
    {
        // x, y, r, g, b, a
        vertex_data := []f32 {
            0, .5, 0, 1, 0, 1,
            .5, .5, 1, 0, 0, 1,
            -.5, -.5, 0, 0, 1, 1
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

        h_result = device->CreateBuffer(&vertex_buffer_desc, &vertex_subresource_data, &vertex_buffer)
        assert(h_result == 0)
    }

    for quit := false; !quit; {
        for e: sdl.Event; sdl.PollEvent(&e); {
            #partial switch e.type {
                case .QUIT:
                    quit = true
                case .KEYDOWN:
                    if e.key.keysym.sym == sdl.Keycode.ESCAPE {
                        quit = true
                    }
            }
        }

        bg_color := [4]f32 {.15, .15, .17, 1}
        device_ctx->ClearRenderTargetView(frame_buffer_view, &bg_color)

        win_rect : windows.RECT
        windows.GetClientRect(native_window, &win_rect)
        viewport := d3d.VIEWPORT {
            0, 0, 
            f32(win_rect.right - win_rect.left), f32(win_rect.bottom - win_rect.top),
            0, 1
        }

        device_ctx->RSSetViewports(1, &viewport)

        device_ctx->IASetPrimitiveTopology(.TRIANGLELIST)
        device_ctx->IASetInputLayout(input_layout)

        device_ctx->VSSetShader(vertex_shader, nil, 0)
        device_ctx->PSSetShader(pixel_shader, nil, 0)

        device_ctx->IASetVertexBuffers(0, 1, &vertex_buffer, &stride, &offset)
        device_ctx->OMSetRenderTargets(1, &frame_buffer_view, nil)

        device_ctx->Draw(vertex_count, 0)

        swap_chain->Present(1, {})
    }
}
