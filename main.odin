package main

import "core:fmt"

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
        "D3d Test", 
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
            Flags = { .BGRA_SUPPORT, .DEBUG },
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
            
            fmt.printfln("Graphics Device: %v", adapter_desc.Description)

            
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
    	    Flags       = { .NONPREROTATED },
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

    for quit := false; !quit; {
        for e: sdl.Event; sdl.PollEvent(&e); {
            #partial switch e.type {
                case .QUIT:
                    quit = true
            }
        }
    }
}

bite :: proc() -> (u32, i32) { 
    return 1, 2
}