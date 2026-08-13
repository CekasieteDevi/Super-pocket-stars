class_name Cancha
extends Control

## Cancha dibujada por código — Fase 8. Placeholder sin pixel art (eso es
## fase 9): un rectángulo verde con líneas, suficiente para ubicar la
## pelota mientras no haya arte real.


func _draw() -> void:
	var w := size.x
	var h := size.y

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.11, 0.45, 0.13))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
	draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, h), Color.WHITE, 2.0)
	draw_arc(Vector2(w / 2.0, h / 2.0), h * 0.16, 0, TAU, 32, Color.WHITE, 2.0)

	var area_w := w * 0.12
	var area_h := h * 0.55
	draw_rect(Rect2(Vector2(0, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)
	draw_rect(Rect2(Vector2(w - area_w, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
