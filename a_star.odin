package pfind

import rl     "vendor:raylib"
import fmt    "core:fmt"
import noise  "core:math/noise"
import linalg "core:math/linalg"
import pq     "core:container/priority_queue"

BASICALLY_INFINITY :: 100000000000000000

path_info :: struct {
    start     : coord,
    goal      : coord,
    path      : []coord,
    path_tree : map[coord]coord,
    found     : bool,
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

f_score : map[coord]f64 // in global scope so that the priority queue "less" function can see it

a_star :: proc(ch: ^chunk, start, goal: coord) -> (path: path_info) {

    path.start = start
    path.goal  = goal

    came_from := make(map[coord]coord)
    //defer delete(came_from)

    // g_score[n] is the cheapest currently-known path from start to n
    g_score := make(map[coord]f64)
    defer delete(g_score)
    g_score[start] = 0

    // f_score[n] represents our current best guess as to how cheap a 
    // path could be from start to finish if it goes through n.
    f_score = make(map[coord]f64)
    defer delete(f_score)
    f_score[start] = heuristic(start, goal)

    pq_coord_less :: proc(a, b: coord) -> bool {return safe_access(f_score, a) < safe_access(f_score, b)}
    open_set : pq.Priority_Queue(coord)
    pq.init(&open_set, pq_coord_less, pq.default_swap_proc(coord))
    defer pq.destroy(&open_set)
    pq.push(&open_set, start)

    for pq.len(open_set) > 0 {

        // current is the node in open_set having the lowest f_score
        current := pq.pop(&open_set)
        if current == goal {
            path.path_tree = came_from
            path.path = reconstruct_path(&came_from, goal)
            path.found = true
            return
        }

        for neighbor in traversable_neighbors(ch, current) {
            tentative_g_score := safe_access(g_score, current) + dist(current, neighbor)
            if tentative_g_score < safe_access(g_score, neighbor) {
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g_score
                f_score[neighbor] = tentative_g_score + heuristic(neighbor, goal)
                add_if_not_exists(&open_set, neighbor)
            }
        }
    }
    path.path_tree = came_from
    path.found = false
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
    return dist(s,e) * 1.5
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

display_path :: proc(path: path_info) {

    // path traversed
    for i in 0..<len(path.path)-1 {
        seg_start := path.path[i]
        seg_end   := path.path[i+1]
        
        cube_pos := rl.Vector3{f32(seg_start.x),f32(seg_start.y),f32(seg_start.z)} - CHUNK_DISPLAY_POS_OFFSET
        rl.DrawCubeV(cube_pos, {0.2, 0.2, 0.2}, {255,255,255,255})

        seg_start_pos := rl.Vector3{f32(seg_start.x),f32(seg_start.y),f32(seg_start.z)} - CHUNK_DISPLAY_POS_OFFSET
        seg_end_pos   := rl.Vector3{f32(seg_end.x),f32(seg_end.y),f32(seg_end.z)} - CHUNK_DISPLAY_POS_OFFSET
        rl.DrawLine3D(seg_start_pos, seg_end_pos, {255,255,255,255})
    }

    // goal and start
    display_column_wire(path.start, rl.RAYWHITE)
    display_block_wire (path.start, rl.RAYWHITE)
    display_column_wire(path.goal, rl.GREEN)
    display_block_wire (path.goal, rl.GREEN)

    // path tree explored
    for to, from in path.path_tree {
        to_pos := rl.Vector3{f32(to.x),f32(to.y),f32(to.z)} - CHUNK_DISPLAY_POS_OFFSET
        from_pos := rl.Vector3{f32(from.x),f32(from.y),f32(from.z)} - CHUNK_DISPLAY_POS_OFFSET
        rl.DrawCubeV(to_pos, {0.2, 0.2, 0.2}, {255,255,255,100})
        rl.DrawLine3D(to_pos, from_pos, {255,255,255,50})

        
    }
}

display_path_tree :: proc(path: path_info) {
    
}