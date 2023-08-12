package pfind

import rl   "vendor:raylib"
import fmt  "core:fmt"
import rand "core:math/rand"
import pq     "core:container/priority_queue"

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 800

FRAMES_PER_SEC :: 60
ITER_PER_FRAME :: 1

REGEN_WORLD :: false

main :: proc() {

    rl.SetTraceLogLevel(.ERROR)

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "pfind")

    camera := rl.Camera3D{}

    camera.position   = {35, 35, 35}
    camera.target     = {0, 0, 0}
    camera.up         = {0, 0, 1}
    camera.fovy       = 45
    camera.projection = .ORTHOGRAPHIC

    if FRAMES_PER_SEC != -1 {
        rl.SetTargetFPS(FRAMES_PER_SEC)
    }

    this_chunk := generate_chunk(
        rand.int63(), 
        height_scale = 5, 
        threshold = 7, 
        noise_scale = 20,
    )

    start_coord := random_ground_coord(this_chunk)
    end_coord := random_ground_coord(this_chunk)

    path := a_star_init(this_chunk, start_coord, end_coord)

    // main display loop
    for !rl.WindowShouldClose() {
        //rl.UpdateCamera(&camera, .THIRD_PERSON)
        rl.UpdateCamera(&camera, .ORBITAL)
        //rl.UpdateCameraPro(&camera, {0,0,0}, {0,0,0}, 1)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)

            if !path.finished {
                for i in 0..<ITER_PER_FRAME {
                    a_star_iter(&path)
                    if path.finished do break
                }
            } else {
                if REGEN_WORLD {
                    free(this_chunk)
                    this_chunk = generate_chunk(
                        rand.int63(), 
                        height_scale = 5, 
                        threshold = 11, 
                        noise_scale = 20,
                    )
                }

                if path.found {
                    start_coord = end_coord
                } else {
                    start_coord = random_ground_coord(this_chunk)
                }

                end_coord = random_ground_coord(this_chunk)

                delete(path.came_from)
                delete(path.g_score)
                delete(f_score)
                pq.destroy(&path.open_set)
                delete(path.path)

                path = a_star_init(this_chunk, start_coord, end_coord)
            }

            display_chunk(this_chunk)
            display_path(path,true, 10)

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