package pfind

import rl   "vendor:raylib"
import fmt  "core:fmt"
import rand "core:math/rand"

SCREEN_WIDTH :: 1200
SCREEN_HEIGHT :: 1000

REGEN_INTERVAL :: 1

main :: proc() {

    rl.SetTraceLogLevel(.ERROR)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "pfind")

    camera := rl.Camera3D{}

    camera.position   = {35, 35, 35}
    camera.target     = {0, 0, 0}
    camera.up         = {0, 0, 1}
    camera.fovy       = 45
    camera.projection = .ORTHOGRAPHIC

    rl.SetTargetFPS(60)

    this_chunk := generate_chunk(rand.int63())

    // generate start coordinate
    start_coord : coord = {
        rand.int31() % CHUNK_DIM_X,
        rand.int31() % CHUNK_DIM_Y,
        CHUNK_DIM_Z}
    for safe_get_block(this_chunk, start_coord) != .solid {
        start_coord.z -= 1
    }
    start_coord.z += 1
    
    // generate end/goal coordinate
    end_coord : coord = { rand.int31() % CHUNK_DIM_X, rand.int31() % CHUNK_DIM_Y, CHUNK_DIM_Z}
    for safe_get_block(this_chunk, end_coord) != .solid {
        end_coord.z -= 1
    }
    end_coord.z += 1

    path := a_star(this_chunk, start_coord, end_coord)

    // main display loop
    regen_time := 0.0
    for !rl.WindowShouldClose() {
        rl.UpdateCamera(&camera, .ORBITAL)
        //rl.UpdateCameraPro(&camera, {0,0,0}, {}, 0)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)

            // regenerate
            if rl.GetTime() > regen_time + REGEN_INTERVAL {
                regen_time = rl.GetTime()

                free(this_chunk) // deallocate previous chunk
                this_chunk = generate_chunk(rand.int63())

                start_coord = random_ground_coord(this_chunk)
                end_coord = random_ground_coord(this_chunk)

                delete(path.path_tree) // deallocate previous path tree
                path = a_star(this_chunk, start_coord, end_coord)

            }

            display_chunk(this_chunk)
            display_path(path)

        rl.EndMode3D()
        rl.EndDrawing()
    }
}

random_ground_coord :: proc(ch: ^chunk) -> coord {
    c := coord{
        rand.int31() % CHUNK_DIM_X,
        rand.int31() % CHUNK_DIM_Y,
        CHUNK_DIM_Z-1}
    for safe_get_block(ch, c) != .solid &&
        safe_get_block(ch, c) != .inaccessable {
        c.z -= 1
    }
    c.z += 1
    return c
}