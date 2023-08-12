package pfind

import rl     "vendor:raylib"
import fmt    "core:fmt"
import noise  "core:math/noise"
import linalg "core:math/linalg"

CHUNK_DIM_X :: 32
CHUNK_DIM_Y :: 32
CHUNK_DIM_Z :: 16

CHUNK_DISPLAY_POS_OFFSET :: rl.Vector3{CHUNK_DIM_X/2-0.5, CHUNK_DIM_Y/2-0.5, CHUNK_DIM_Z/2-0.5}

coord :: [3]i32

ID :: enum u32 {
    inaccessable = 0,
    air   = 1,
    solid = 2,
}

chunk :: [CHUNK_DIM_X][CHUNK_DIM_Y][CHUNK_DIM_Z]ID

safe_get_block :: proc(ch: ^chunk, c: coord) -> ID {
    if (0 > c.x || c.x >= CHUNK_DIM_X ||
        0 > c.y || c.y >= CHUNK_DIM_Y ||
        0 > c.z || c.z >= CHUNK_DIM_Z) {
        return .inaccessable
    }
    return ch[c.x][c.y][c.z]
}

generate_chunk :: proc(seed: i64) -> (ch: ^chunk) {
    ch = new(chunk)
    for x in 0..<CHUNK_DIM_X {
    for y in 0..<CHUNK_DIM_Y {
    for z in 0..<CHUNK_DIM_Z {
        
        noise_sample := noise.noise_3d_improve_xy(seed, {f64(x)/15,f64(y)/15,0})

        if (noise_sample * 6 + f32(z)) > 7 {
            ch[x][y][z] = .air
        } else {
            ch[x][y][z] = .solid
        }
    }
    }
    }
    return
}

display_chunk :: proc(ch: ^chunk) {
    for x in 0..<CHUNK_DIM_X {
    for y in 0..<CHUNK_DIM_Y {
    for z in 0..<CHUNK_DIM_Z {

        cube_pos := rl.Vector3{f32(x),f32(y),f32(z)} - CHUNK_DISPLAY_POS_OFFSET
        
        // coloring shit
        f_color := ([4]f32{f32(x), f32(y), f32(z), 255} /
                    {CHUNK_DIM_X, CHUNK_DIM_Y, CHUNK_DIM_Z, 1} *
                    {230, 230, 230, 1})
        color   := [4]u8{u8(f_color.r),u8(f_color.g),u8(f_color.b),u8(f_color.a)}
        wire_color :=  [4]u8{20, 20, 20, 0} + color

        switch ch[x][y][z] {
        case .solid:
            rl.DrawCubeV(cube_pos, {1, 1, 1}, transmute(rl.Color) color)
            rl.DrawCubeWiresV(
                cube_pos,
                {1, 1, 1},
                transmute(rl.Color) wire_color)
        case .air:
        case .inaccessable:
            rl.DrawCubeV(cube_pos, {1, 1, 1}, rl.RED)
            rl.DrawCubeWiresV(cube_pos, {1, 1, 1}, rl.BLACK)

        }
    }
    }
    }
}

display_block_wire :: proc(c: coord, color : rl.Color) {
    cube_pos := rl.Vector3{f32(c.x),f32(c.y),f32(c.z)} - CHUNK_DISPLAY_POS_OFFSET
    rl.DrawCubeWiresV(cube_pos, {1, 1, 1}, color)
}

display_block :: proc(c: coord, color : rl.Color) {
    cube_pos := rl.Vector3{f32(c.x),f32(c.y),f32(c.z)} - CHUNK_DISPLAY_POS_OFFSET
    rl.DrawCubeV(cube_pos, {1, 1, 1}, color)
}

display_column :: proc(c: coord, color : rl.Color) {
    cube_pos := rl.Vector3{f32(c.x),f32(c.y),f32(c.z)} - CHUNK_DISPLAY_POS_OFFSET
    cube_pos.z = 0
    rl.DrawCubeV(cube_pos, {1, 1, CHUNK_DIM_Z}, color)
}

display_column_wire :: proc(c: coord, color : rl.Color) {
    cube_pos := rl.Vector3{f32(c.x),f32(c.y),f32(c.z)} - CHUNK_DISPLAY_POS_OFFSET
    cube_pos.z = 0
    rl.DrawCubeWiresV(cube_pos, {1, 1, CHUNK_DIM_Z}, color)
}