package pfind

import rl   "vendor:raylib"
import fmt  "core:fmt"
import rand "core:math/rand"
import pq     "core:container/priority_queue"

SCREEN_WIDTH :: 1500
SCREEN_HEIGHT :: 800

FRAMES_PER_SEC        :: -1
WAIT_AFTER_FINISHED   :: 0.5
DRAW_SECONDARY_PATH   :: true
SECONDARY_PATH_HEIGHT :: 15
DRAW_ONLY_TOP         :: false

HEURISTIC_WEIGHT     :: 1.5
NODE_ABORT_THRESHOLD :: 1000
ITER_PER_FRAME       :: 1

REGEN_WORLD           :: false
CHUNK_HEIGHT_SCALE    :: 10
CHUNK_SOLID_THRESHOLD :: 7
CHUNK_NOISE_SCALE     :: 15

main :: proc() {

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({.WINDOW_RESIZABLE})

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
        height_scale = CHUNK_HEIGHT_SCALE,
        threshold = CHUNK_SOLID_THRESHOLD, 
        noise_scale = CHUNK_NOISE_SCALE,
    )

    start_coord := random_ground_coord(this_chunk)
    end_coord := random_ground_coord(this_chunk)

    path := a_star_create(this_chunk, start_coord, end_coord, HEURISTIC_WEIGHT, NODE_ABORT_THRESHOLD)

    // main display loop
    stopwatch := rl.GetTime()
    for !rl.WindowShouldClose() {
        //rl.UpdateCamera(&camera, .THIRD_PERSON)
        rl.UpdateCamera(&camera, .ORBITAL)
        //rl.UpdateCameraPro(&camera, {0,0,0}, {0,0,0}, 1)

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        rl.BeginMode3D(camera)

            if path.status == .exploring || path.status == .initialized {
                for i in 0..<ITER_PER_FRAME {
                    a_star_iter(path)
                    if has_finished(path) {
                        stopwatch = rl.GetTime()
                        break
                    }
                }
            } else if stopwatch + WAIT_AFTER_FINISHED < rl.GetTime() {

                if REGEN_WORLD {
                    free(this_chunk)
                    this_chunk = generate_chunk(
                        rand.int63(), 
                        height_scale = CHUNK_HEIGHT_SCALE,
                        threshold = CHUNK_SOLID_THRESHOLD,
                        noise_scale = CHUNK_NOISE_SCALE,
                    )
                }

                if has_succeeded(path) {
                    start_coord = end_coord
                } else {
                    start_coord = random_ground_coord(this_chunk)
                }

                end_coord = random_ground_coord(this_chunk)

                a_star_cleanup(path)

                path = a_star_create(this_chunk, start_coord, end_coord, HEURISTIC_WEIGHT, NODE_ABORT_THRESHOLD)
            }

            display_chunk(this_chunk)
            display_path(path, DRAW_SECONDARY_PATH, SECONDARY_PATH_HEIGHT)

        rl.EndMode3D()

        rl.DrawText("status: ", 10, 10, 20, rl.RAYWHITE);
        status_color := rl.LIGHTGRAY
        if has_failed(path) {
            status_color = rl.RED
        } else if has_succeeded(path) {
            status_color = rl.GREEN
        }
        rl.DrawText(fmt.ctprintf("%s", path.status), 90, 10, 20, status_color);

        rl.DrawText(fmt.ctprintf("path length: %d", len(path.path)), 10, 30, 20, rl.RAYWHITE);
        rl.DrawText(fmt.ctprintf("path distance: %.1fm", path_distance(path)), 10, 50, 20, rl.RAYWHITE);
        rl.DrawText(fmt.ctprintf("nodes explored: %d (%.1f%%)", len(path.came_from), f64(len(path.came_from))*100/f64(CHUNK_DIM_X*CHUNK_DIM_Y)), 10, 70, 20, rl.RAYWHITE);
        rl.DrawText(fmt.ctprintf("iterations: %d", path.iteration_count), 10, 90, 20, rl.RAYWHITE);

        rl.DrawText("start:", 10, 130, 20, rl.RAYWHITE);
        rl.DrawText(fmt.ctprintf("%v", path.start), 80, 130, 20, rl.RAYWHITE);
        rl.DrawText("goal:", 10, 150, 20, rl.RAYWHITE);
        rl.DrawText(fmt.ctprintf("%v", path.goal), 80, 150, 20, rl.RAYWHITE);


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