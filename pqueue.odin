package pfind

import "core:builtin"

// yes im modifying corelib code

pqueue :: struct {
	queue: [dynamic]coord,
    f_score_ptr : ^map[coord]f64,
	less:  proc(a, b: coord, pq: ^pqueue) -> bool,
	swap:  proc(q: []coord, i, j: int),
}

DEFAULT_CAPACITY :: 16

default_swap_proc :: proc($T: typeid) -> proc(q: []T, i, j: int) {
	return proc(q: []T, i, j: int) {
		q[i], q[j] = q[j], q[i]
	}
}

init :: proc(pq: ^pqueue, f_score_ptr: ^map[coord]f64, allocator := context.allocator) {
	if pq.queue.allocator.procedure == nil {
		pq.queue.allocator = allocator
	}
	pq.f_score_ptr = f_score_ptr
	reserve(pq, 100)
	pq.less = proc(a, b: coord, pq: ^pqueue) -> bool {
        return safe_access(pq.f_score_ptr^, a) < safe_access(pq.f_score_ptr^, b)
    }
	pq.swap = proc(q: []coord, i, j: int) {
		q[i], q[j] = q[j], q[i]
	}
}

destroy :: proc(pq: ^pqueue) {
	delete(pq.queue)
	clear(pq)
}

reserve :: proc(pq: ^pqueue, capacity: int) {
	builtin.reserve(&pq.queue, capacity)
}
clear :: proc(pq: ^pqueue) {
	builtin.clear(&pq.queue)
}
length :: proc(pq: pqueue) -> int {
	return builtin.len(pq.queue)
}
cap :: proc(pq: pqueue) -> int {
	return builtin.cap(pq.queue)
}

_shift_down :: proc(pq: ^pqueue, i0, n: int) -> bool {
	// O(n log n)
	if 0 > i0 || i0 > n {
		return false
	}
	
	i := i0
	queue := pq.queue[:]
	
	for {
		j1 := 2*i + 1
		if j1 < 0 || j1 >= n {
			break
		}
		j := j1
		if j2 := j1+1; j2 < n && pq.less(queue[j2], queue[j1], pq) {
			j = j2
		}
		if !pq.less(queue[j], queue[i], pq) {
			break
		}
		
		pq.swap(queue, i, j)
		i = j
	}
	return i > i0
}

_shift_up :: proc(pq: ^pqueue, j: int) {
	j := j
	queue := pq.queue[:]
	for 0 <= j {
		i := (j-1)/2
		if i == j || !pq.less(queue[j], queue[i], pq) {
			break
		}
		pq.swap(queue, i, j)
		j = i
	}
}

// NOTE(bill): When an element at index 'i' has changed its value, this will fix the
// the heap ordering. This is using a basic "heapsort" with shift up and a shift down parts.
fix :: proc(pq: ^pqueue, i: int) {
	if !_shift_down(pq, i, builtin.len(pq.queue)) {
		_shift_up(pq, i)
	}
}

push :: proc(pq: ^pqueue, value: coord) {
	append(&pq.queue, value)
	_shift_up(pq, builtin.len(pq.queue)-1)
}

pop :: proc(pq: ^pqueue, loc := #caller_location) -> (value: coord) {
	assert(condition=builtin.len(pq.queue)>0, loc=loc)
	
	n := builtin.len(pq.queue)-1
	pq.swap(pq.queue[:], 0, n)
	_shift_down(pq, 0, n)
	return builtin.pop(&pq.queue)
}

pop_safe :: proc(pq: ^pqueue, loc := #caller_location) -> (value: coord, ok: bool) {
	if builtin.len(pq.queue) > 0 {
		n := builtin.len(pq.queue)-1
		pq.swap(pq.queue[:], 0, n)
		_shift_down(pq, 0, n)
		return builtin.pop_safe(&pq.queue)
	}
	return
}

remove :: proc(pq: ^pqueue, i: int) -> (value: coord, ok: bool) {
	n := builtin.len(pq.queue)
	if 0 <= i && i < n {
		if n != i {
			pq.swap(pq.queue[:], i, n)
			_shift_down(pq, i, n)
			_shift_up(pq, i)
		}
		value, ok = builtin.pop_safe(&pq.queue)
	}
	return
}