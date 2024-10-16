package window

import sdl "vendor:sdl2"
import sys "core:sys/windows"
import "vendor:directx/dxgi"

sdl_window      : ^sdl.Window
native_handle   : sys.HWND

init :: proc(width, height : i32, title: cstring) {
    sdl.Init({ .VIDEO, .EVENTS })
    sdl.SetHintWithPriority(sdl.HINT_RENDER_DRIVER, "direct3d11", .OVERRIDE)

    sdl_window = sdl.CreateWindow(
        title, 
        sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
        width, height, 
        { }
    )

    window_system_info: sdl.SysWMinfo
    sdl.GetVersion(&window_system_info.version)
    sdl.GetWindowWMInfo(sdl_window, &window_system_info)
    assert(window_system_info.subsystem == .WINDOWS)

    native_handle = dxgi.HWND(window_system_info.info.win.window)
}

deinit :: proc() {
    defer sdl.DestroyWindow(sdl_window)
    sdl.Quit()
}