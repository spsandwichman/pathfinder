package pfind

import rl     "vendor:raylib"
import fmt    "core:fmt"
import noise  "core:math/noise"
import linalg "core:math/linalg"
import pq     "core:container/priority_queue"

BASICALLY_INFINITY :: 100000000000000000

a_star_info :: struct {
    start     : coord,
    goal      : coord,
    path      : []coord,
    chunk     : ^chunk,
    came_from : map[coord]coord,
    g_score   : map[coord]f64,
    open_set  : pq.Priority_Queue(coord),
    found     : bool,
    finished  : bool,
}

reconstruct_path :: proc(came_from:^map[coord]coord, goal: coord) -> []coord {
    current := goal
    path := make([dynamic]coord)
    append(&path, current)
    for (current in came_from) {
        current = came_from[current]
        inject_at(&path, 0, current)
    }
    return path[:]
}

f_score : map[coord]f64 
// in global scope so that the priority queue "less" function can see it
// fix later please

a_star_init :: proc(ch: ^chunk, start, goal: coord) -> (info: a_star_info) {
    info.start = start
    info.goal  = goal
    info.chunk = ch
    info.finished = false

    info.came_from = make(map[coord]coord)
    //defer delete(came_from)

    // g_score[n] is the cheapest currently-known path from start to n
    info.g_score = make(map[coord]f64)
    info.g_score[start] = 0

    // f_score[n] represents our current best guess as to how cheap a 
    // path could be from start to finish if it goes through n.
    f_score = make(map[coord]f64)
    f_score[start] = heuristic(start, goal)

    pq_coord_less :: proc(a, b: coord) -> bool {
        return safe_access(f_score, a) < safe_access(f_score, b)
    }
    pq.init(&info.open_set, pq_coord_less, pq.default_swap_proc(coord))
    pq.push(&info.open_set, start)

    return
}

a_star_iter :: proc(info: ^a_star_info) {

    

    if pq.len(info.open_set) > 0 {

        // current is the node in open_set having the lowest f_score
        current := pq.pop(&info.open_set)
        if current == info.goal {
            info.path = reconstruct_path(&info.came_from, info.goal)
            info.found = true
            info.finished = true
            return
        }

        for neighbor in traversable_neighbors(info.chunk, current) {
            tentative_g_score := safe_access(info.g_score, current) + dist(current, neighbor)
            if tentative_g_score < safe_access(info.g_score, neighbor) {
                info.came_from[neighbor] = current
                info.g_score[neighbor] = tentative_g_score
                f_score[neighbor] = tentative_g_score + heuristic(neighbor, info.goal)
                add_if_not_exists(&info.open_set, neighbor)
                info.path = reconstruct_path(&info.came_from, neighbor)
            }
        }
    } else {
        info.finished = true
        return
    }
    return
}

safe_access :: proc(m: map[$T]$R, c: T) -> R { return (c in m ? m[c] : BASICALLY_INFINITY)}

// definitely a better way to do this
add_if_not_exists :: proc(q: ^pq.Priority_Queue($T), i: T) {
    does_exist := false
    for item in q.queue {
        if item == i {
            does_exist = true
            break
        }
    }
    if !does_exist {
        pq.push(q, i)
    }
}

heuristic :: proc(s, e: coord) -> f64 {
    return dist(s, e) * 2
}

dist :: proc(s, e: coord) -> f64 {
    diff := [3]f64{
        f64(s.x - e.x),
        f64(s.y - e.y),
        f64(s.z - e.z)}
    return abs(linalg.vector_length(diff))
}

traversable_neighbors :: proc(ch: ^chunk, pos: coord) -> []coord {
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
    return n[:]
}

display_path :: proc(path: a_star_info, secondary: bool, secondary_offset: i32) {

    // path traversed
    for i in 0..<len(path.path)-1 {
        seg_start := path.path[i]
        seg_end   := path.path[i+1]
        
        dist_grad := dist(path.start, seg_start)/dist(path.start, path.goal)

        col := rl.RAYWHITE //interpolate_color(rl.GREEN, rl.BLUE, dist_grad)

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

    // goal and start
    display_block_wire(path.start, rl.DARKBLUE)
    display_block_wire(path.goal, rl.DARKGREEN)
    display_block(path.start, rl.BLUE)
    display_block(path.goal, rl.GREEN)
    if secondary {
        display_block_wire(path.start + {0,0,secondary_offset}, rl.DARKBLUE)
        display_block_wire(path.goal + {0,0,secondary_offset}, rl.DARKGREEN)
        display_block(path.start + {0,0,secondary_offset}, rl.BLUE)
        display_block(path.goal + {0,0,secondary_offset}, rl.GREEN)
    }


    // path tree explored
    for to, from in path.came_from {
        to_pos := rl.Vector3{f32(to.x),f32(to.y),f32(to.z)} - CHUNK_DISPLAY_POS_OFFSET
        from_pos := rl.Vector3{f32(from.x),f32(from.y),f32(from.z)} - CHUNK_DISPLAY_POS_OFFSET
        rl.DrawCubeV(to_pos, {0.2, 0.2, 0.2}, {255,255,255,50})
        rl.DrawLine3D(to_pos, from_pos, {255,255,255,50})

        if secondary {
            rl.DrawCubeV(to_pos + {0,0,f32(secondary_offset)}, {0.2, 0.2, 0.2}, {255,255,255,50})
            rl.DrawLine3D(to_pos + {0,0,f32(secondary_offset)}, from_pos + {0,0,f32(secondary_offset)}, {255,255,255,50})
        }
    }
}

interpolate_color :: proc(col1, col2 : rl.Color, mix: f64) -> rl.Color {
    f_color1 := [4]f64{f64(col1.r),f64(col1.b),f64(col1.g),f64(col1.a)}
    f_color2 := [4]f64{f64(col2.r),f64(col2.b),f64(col2.g),f64(col2.a)}
    f_color_mix := (f_color1 * mix) + (f_color2 * 1/mix)
    return {u8(f_color_mix.r),u8(f_color_mix.g),u8(f_color_mix.b),u8(f_color_mix.a)}
}