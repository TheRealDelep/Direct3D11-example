package main

import "core:fmt"
import "core:strings"
import "core:sys/windows"

import sdl "vendor:sdl2"
import d3d "vendor:directx/d3d11"
import d3d_comp "vendor:directx/d3d_compiler"
import "vendor:directx/dxgi"

import "window"
import "graphics"

window_size := [2]i32 {800, 600}

main :: proc() {
    // Sdl initialization
    window.init(window_size.x, window_size.y, "D3D-Test")
    defer window.deinit()

    graphics.init()
    graphics.draw_command = get_triangle_draw_cmd() 

    quad_cmd := get_texture_quad_draw_cmd()

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

        graphics.render()
    }
}
