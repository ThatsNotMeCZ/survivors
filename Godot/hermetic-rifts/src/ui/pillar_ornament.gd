@tool
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(130, 76)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var c := Color(UiAtlas.BRASS_DIM, 0.8)
	var sx: float = size.x / 120.0
	var sy: float = size.y / 80.0
	var diamond := PackedVector2Array([
		Vector2(60.0, 8.0) * Vector2(sx, sy),
		Vector2(78.0, 26.0) * Vector2(sx, sy),
		Vector2(60.0, 44.0) * Vector2(sx, sy),
		Vector2(42.0, 26.0) * Vector2(sx, sy),
	])
	draw_polyline(diamond, c, 2.0, true)
	draw_line(diamond[3], diamond[0], c, 2.0, true)
	var steps: int = 16
	var prev := Vector2(20.0, 68.0) * Vector2(sx, sy)
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var nxt := _quad(Vector2(20, 68), Vector2(60, 32), Vector2(100, 68), t) * Vector2(sx, sy)
		draw_line(prev, nxt, c, 1.5, true)
		prev = nxt
	draw_arc(Vector2(60.0, 26.0) * Vector2(sx, sy), 5.0 * minf(sx, sy), 0.0, TAU, 24, c, 1.5, true)


func _quad(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * a + 2.0 * u * t * b + t * t * c
