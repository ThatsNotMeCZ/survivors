class_name SimCollision
extends RefCounted


static func circles_overlap(ax: float, ay: float, ar: float, bx: float, by: float, br: float) -> bool:
	var dx: float = ax - bx
	var dy: float = ay - by
	var r: float = ar + br
	return dx * dx + dy * dy <= r * r


static func aabb_overlap(ax: float, ay: float, ar: float, bx: float, by: float, br: float) -> bool:
	return absf(ax - bx) <= ar + br and absf(ay - by) <= ar + br


static func clampv(value: float, lo: float, hi: float) -> float:
	return maxf(lo, minf(hi, value))


static func push_circles(
	ax: float,
	ay: float,
	ar: float,
	bx: float,
	by: float,
	br: float,
	weight_a: float,
	weight_b: float,
) -> Vector4:
	var dx: float = ax - bx
	var dy: float = ay - by
	var dist: float = hypot(dx, dy)
	var min_dist: float = ar + br
	if dist >= min_dist:
		return Vector4(ax, ay, bx, by)
	if dist < 0.0001:
		return Vector4(ax + min_dist * weight_a, ay, bx - min_dist * weight_b, by)
	var overlap: float = min_dist - dist
	var nx: float = dx / dist
	var ny: float = dy / dist
	return Vector4(
		ax + nx * overlap * weight_a,
		ay + ny * overlap * weight_a,
		bx - nx * overlap * weight_b,
		by - ny * overlap * weight_b,
	)


static func point_to_segment(px: float, py: float, x0: float, y0: float, x1: float, y1: float) -> float:
	var dx: float = x1 - x0
	var dy: float = y1 - y0
	var len2: float = dx * dx + dy * dy
	if len2 == 0.0:
		return hypot(px - x0, py - y0)
	var t: float = ((px - x0) * dx + (py - y0) * dy) / len2
	t = clampf(t, 0.0, 1.0)
	return hypot(px - (x0 + t * dx), py - (y0 + t * dy))


static func hypot(dx: float, dy: float) -> float:
	return sqrt(dx * dx + dy * dy)


static func clamp_to_circle(px: float, py: float, max_dist: float) -> Vector2:
	if max_dist <= 0.0:
		return Vector2.ZERO
	var d: float = sqrt(px * px + py * py)
	if d > max_dist:
		return Vector2((px / d) * max_dist, (py / d) * max_dist)
	return Vector2(px, py)


static func slide_along_circle_rim(
	px: float,
	py: float,
	vx: float,
	vy: float,
	dt: float,
	max_dist: float,
) -> Vector2:
	return clamp_to_circle(px + vx * dt, py + vy * dt, max_dist)
