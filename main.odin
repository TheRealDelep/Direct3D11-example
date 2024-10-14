package main

import "core:fmt"

import sdl "vendor:sdl2"
import d3d "vendor:directx/d3d11"
import d3d_comp "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

window_size := [2]i32 {800, 600}

main :: proc() {
    // Sdl initialization
    window := sdl.CreateWindow("D3d Test", 400, 0, window_size.x, window_size.y, { .})

    if window == nil {
        glfw.Terminate()
        panic("could not create window")
    }
    
    // D3D INITIALIZATION 
    h_result    : d3d.HRESULT

    device      : ^d3d.IDevice
    device_ctx  : ^d3d.IDeviceContext
    
    // base device initialization
    {
        base_device      : ^d3d.IDevice
        base_device_ctx  : ^d3d.IDeviceContext

	    feature_levels := [?]d3d.FEATURE_LEVEL{._11_0}

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
            
            fmt.printfln("Graphics Device: %v", adapter_desc.Description)

            
            h_result = adapter->GetParent(dxgi.IFactory2_UUID, (^rawptr)(&factory))
            assert(h_result == 0)
            adapter->Release()
        }
        
        swap_chain_desc := dxgi.SWAP_CHAIN_DESC1 {
            Width       = 0,
    	    Height      = 0,
    	    Format      = .B8G8R8A8_UNORM,
    	    Stereo      = true,
    	    SampleDesc  = { Count = 1, Quality = 0 },
    	    BufferUsage =  { .RENDER_TARGET_OUTPUT },
    	    BufferCount = 2,
    	    Scaling     = .ASPECT_RATIO_STRETCH,
    	    SwapEffect  = .DISCARD,
    	    AlphaMode   = .UNSPECIFIED,
    	    Flags       = { .NONPREROTATED },
        }

        hwnd := glfw.GetWin32Window(window)
        fmt.println(hwnd)
        h_result = factory->CreateSwapChainForHwnd(
            pDevice = device, 
            hWnd = hwnd, 
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

    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()

        bg_color : [4]f32 = { 0.1, 0.2, 0.6, 1 }
        device_ctx->ClearRenderTargetView(frame_buffer_view, &bg_color)

        swap_chain->Present(1, { .TEST })
    }

    glfw.DestroyWindow(window)
    glfw.Terminate()
}
