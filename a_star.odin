package pfind

import rl     "vendor:raylib"
import fmt    "core:fmt"
import noise  "core:math/noise"
import linalg "core:math/linalg"

BASICALLY_INFINITY :: 100000000000000000

a_star_status :: enum u8 {
    uninitialized,               // default: instance has not been initialized
    initialized,                 // instance has been initialized
    exploring,                   // instance is currently exploring
    success_path_found,          // instance has found a suitable path
    failure_no_path_exists,      // instance has explored all nodes and no suitable path exists
    failure_timed_out,           // instance has reached its iteration abort threshold
}

a_star_instance :: struct {
    start           : coord,
    goal            : coord,
    current         : coord,
    path            : [dynamic]coord,
    chunk           : ^chunk,
    came_from       : map[coord]coord,
    g_score         : map[coord]f64,
    f_score         : map[coord]f64,
    open_set        : pqueue,
    status          : a_star_status,
    h_weight        : f64,
    abort_threshold : u64,
    iteration_count : u64,
}

reconstruct_path :: proc(info: ^a_star_instance) {
    current := info.current
    delete(info.path)
    info.path = make([dynamic]coord)
    append(&info.path, current)
    for (current in info.came_from) {
        current = info.came_from[current]
        inject_at(&info.path, 0, current)
    }
    return
}

a_star_create :: proc(ch: ^chunk, start, goal: coord, h_weight: f64 = 1, failure_threshold: u64 = 0) -> (info: ^a_star_instance) {
    info = new(a_star_instance)

    info.start = start
    info.goal  = goal
    info.chunk = ch
    info.status = .initialized
    info.h_weight = h_weight
    info.abort_threshold = failure_threshold

    info.path = make([dynamic]coord)

    info.came_from = make(map[coord]coord)
    //defer delete(came_from)

    // g_score[n] is the cheapest currently-known path from start to n
    info.g_score = make(map[coord]f64)
    info.g_score[start] = 0

    // f_score[n] represents our current best guess as to how cheap a 
    // path could be from start to finish if it goes through n.
    info.f_score = make(map[coord]f64)
    info.f_score[start] = heuristic(start, goal, info.h_weight)

    init(&info.open_set, &(info.f_score))
    push(&info.open_set, start)

    return
}

a_star_complete :: proc(info: ^a_star_instance) {
    for !has_finished(info) {
        a_star_iter(info)
    }
}

a_star_iter :: proc(info: ^a_star_instance) {

    info.status = .exploring
    info.iteration_count += 1

    if info.abort_threshold != 0 && info.iteration_count > info.abort_threshold {
        info.status = .failure_timed_out
        return
    }

    if length(info.open_set) > 0 {

        // current is the node in open_set having the lowest f_score
        info.current = pop(&info.open_set)
        if info.current == info.goal {
            reconstruct_path(info)
            info.status = .success_path_found
            return
        }
        reconstruct_path(info)

        neighbors := traversable_neighbors(info.chunk, info.current)
        defer delete(neighbors)
        for neighbor in neighbors {
            tentative_g_score := safe_access(info.g_score, info.current) + dist(info.current, neighbor)
            if tentative_g_score < safe_access(info.g_score, neighbor) {
                info.came_from[neighbor] = info.current
                info.g_score[neighbor] = tentative_g_score
                info.f_score[neighbor] = tentative_g_score + heuristic(neighbor, info.goal, info.h_weight)
                add_if_not_exists(&info.open_set, neighbor)
            }
        }
    } else {
        info.status = .failure_no_path_exists
        return
    }
    return
}

a_star_cleanup :: proc(info: ^a_star_instance) {
    delete(info.path)
    delete(info.came_from)
    delete(info.g_score)
    delete(info.f_score)
    destroy(&info.open_set)
    free(info)
}

safe_access :: proc(m: map[$T]$R, c: T) -> R { return (c in m ? m[c] : BASICALLY_INFINITY)}

// definitely a better way to do this
add_if_not_exists :: proc(q: ^pqueue, i: coord) {
    does_exist := false
    for item in q.queue {
        if item == i {
            does_exist = true
            break
        }
    }
    if !does_exist {
        push(q, i)
    }
}

heuristic :: proc(s, e: coord, weight: f64) -> f64 {
    return dist(s, e) * weight
}

dist :: proc(s, e: coord) -> f64 {
    diff := [3]f64{
        f64(s.x - e.x),
        f64(s.y - e.y),
        f64(s.z - e.z)}
    return abs(linalg.vector_length(diff))
}

traversable_neighbors :: proc(ch: ^chunk, pos: coord) -> [dynamic]coord {
    n := make([dynamic]coord, 0, 8)
    for x in i32(-1)..=1 {
    for y in i32(-1)..=1 {
        new_pos := pos + coord{x,y,0}

        if safe_get_block(ch, new_pos) == .air && safe_get_block(ch, new_pos-{0,0,1}) == .solid {
            append(&n, new_pos)
            continue
        }

        if safe_get_block(ch, new_pos+{0,0,1}) == .air && safe_get_block(ch, new_pos) == .solid {
            append(&n, new_pos+{0,0,1})
            continue
        }

        for i in 1..<pos.z {
            if safe_get_block(ch, new_pos-{0,0,i}) == .air && safe_get_block(ch, new_pos-{0,0,i+1}) == .solid {
                append(&n, new_pos-{0,0,i})
                break
            }
        }
    }
    }
    return n
}

display_visited :: proc(path: ^a_star_instance, secondary: bool, secondary_offset: i32) {
    // path tree explored
    path_tree_color := rl.Color{255, 255, 255, 50}
    if has_failed(path) {
        path_tree_color = {230, 41, 55, 200}
    }
    for to, from in path.came_from {
        to_pos := rl.Vector3{f32(to.x),f32(to.y),f32(to.z)} - CHUNK_DISPLAY_POS_OFFSET
        from_pos := rl.Vector3{f32(from.x),f32(from.y),f32(from.z)} - CHUNK_DISPLAY_POS_OFFSET
        rl.DrawCubeV(to_pos, {0.2, 0.2, 0.2}, path_tree_color)
        rl.DrawLine3D(to_pos, from_pos, path_tree_color)

        if secondary {
            rl.DrawCubeV(to_pos + {0,0,f32(secondary_offset)}, {0.2, 0.2, 0.2}, path_tree_color)
            rl.DrawLine3D(to_pos + {0,0,f32(secondary_offset)}, from_pos + {0,0,f32(secondary_offset)}, path_tree_color)
        }
    }
}

display_waypoints :: proc(path: ^a_star_instance, secondary: bool, secondary_offset: i32) {
    // goal and start
    start_color      := rl.BLUE      //rl.RAYWHITE
    start_wire_color := rl.DARKBLUE  //rl.GRAY
    goal_color       := rl.GREEN     //rl.RAYWHITE
    goal_wire_color  := rl.DARKGREEN //rl.GRAY
    display_block_wire(path.start, start_wire_color)
    display_block_wire(path.goal, goal_wire_color)
    display_block(path.start, start_color)
    display_block(path.goal, goal_color)
    if secondary {
        display_block_wire(path.start + {0,0,secondary_offset}, start_wire_color)
        display_block_wire(path.goal + {0,0,secondary_offset}, goal_wire_color)
        display_block(path.start + {0,0,secondary_offset}, start_color)
        display_block(path.goal + {0,0,secondary_offset}, goal_color)
    }
}

display_path :: proc(path: ^a_star_instance, secondary: bool, secondary_offset: i32, color_override : rl.Color = {0,0,0,0}) {

    // path traversed
    if path.status == .exploring || has_succeeded(path) {
        for i in 0..<len(path.path)-1 {
            seg_start := path.path[i]
            seg_end   := path.path[i+1]

            dist_grad := dist(path.start, seg_start)/dist(path.start, path.goal)

            col := rl.RAYWHITE //interpolate_color(rl.GREEN, rl.BLUE, dist_grad)

            if has_succeeded(path) {
                col = rl.GREEN
            }

            if color_override != {0,0,0,0} {
                col = color_override
            }

            cube_pos := rl.Vector3{f32(seg_start.x),f32(seg_start.y),f32(seg_start.z)} - CHUNK_DISPLAY_POS_OFFSET
            rl.DrawCubeV(cube_pos, {0.2, 0.2, 0.2}, col)

            seg_start_pos := rl.Vector3{f32(seg_start.x),f32(seg_start.y),f32(seg_start.z)} - CHUNK_DISPLAY_POS_OFFSET
            seg_end_pos   := rl.Vector3{f32(seg_end.x),f32(seg_end.y),f32(seg_end.z)} - CHUNK_DISPLAY_POS_OFFSET
            rl.DrawLine3D(seg_start_pos, seg_end_pos, col)

            if secondary {
                rl.DrawCubeV(cube_pos + {0,0,f32(secondary_offset)}, {0.2, 0.2, 0.2}, col)
                rl.DrawLine3D(seg_start_pos + {0,0,f32(secondary_offset)}, seg_end_pos + {0,0,f32(secondary_offset)}, col)
            }
        }
    }
}

path_distance :: proc(path: ^a_star_instance) -> (distance: f64) {
    for i in 0..<len(path.path)-1 {
        distance += dist(path.path[i],path.path[i+1])
    }
    return
}

has_finished :: proc(path: ^a_star_instance) -> bool{
    return (path.status == .success_path_found ||
            path.status == .failure_timed_out ||
            path.status == .failure_no_path_exists)
}

has_failed :: proc(path: ^a_star_instance) -> bool {
    return (path.status == .failure_timed_out ||
            path.status == .failure_no_path_exists)
}

has_succeeded :: proc(path: ^a_star_instance) -> bool {
    return (path.status == .success_path_found)
}

// interpolate_color :: proc(col1, col2 : rl.Color, mix: f64) -> rl.Color {
//     f_color1 := [4]f64{f64(col1.r),f64(col1.b),f64(col1.g),f64(col1.a)}
//     f_color2 := [4]f64{f64(col2.r),f64(col2.b),f64(col2.g),f64(col2.a)}
//     f_color_mix := (f_color1 * mix) + (f_color2 * 1/mix)
//     return {u8(f_color_mix.r),u8(f_color_mix.g),u8(f_color_mix.b),u8(f_color_mix.a)}
// }