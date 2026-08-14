class_name Cancha
extends Control

## Cancha dibujada por código — Fase 8, pulida con 22 posiciones fijas
## (Fase de pulido del partido animado). Sin pixel art (eso sigue
## pendiente) ni movimiento real de jugadores: el motor sigue sin calcular
## posiciones x/y por jugador durante el partido, solo zona de la jugada
## (armado/último tercio) y la posición del que participa. Lo que se
## dibuja acá es una FORMACIÓN FIJA por equipo (11 puntos cada uno, según
## FORMACION_SLOTS) para que la cancha se sienta poblada — el que participa
## de la jugada actual se resalta más grande, en vez de mover los 22 de
## verdad.

## Coordenadas normalizadas (0..1) del lado local, atacando hacia la
## derecha; el visitante espeja x (1-x) y ataca hacia la izquierda. Sigue
## la formación real de Team.FORMACION: 1 ARQ, 2 DFC, 2 LAT, 2 MC, 1 MCO,
## 2 EXT, 1 DC.
const FORMACION_SLOTS := {
	"ARQ": [{"x": 0.05, "y": 0.5}],
	"DFC": [{"x": 0.16, "y": 0.35}, {"x": 0.16, "y": 0.65}],
	"LAT": [{"x": 0.18, "y": 0.12}, {"x": 0.18, "y": 0.88}],
	"MC": [{"x": 0.34, "y": 0.38}, {"x": 0.34, "y": 0.62}],
	"MCO": [{"x": 0.42, "y": 0.5}],
	"EXT": [{"x": 0.48, "y": 0.15}, {"x": 0.48, "y": 0.85}],
	"DC": [{"x": 0.50, "y": 0.5}],
}

const COLOR_LOCAL := Color(0.95, 0.75, 0.15)
const COLOR_VISITANTE := Color(0.35, 0.65, 0.95)
const RADIO_NORMAL := 7.0
const RADIO_RESALTADO := 12.0

## Posición cuyo círculo se dibuja más grande — "" si ninguna. Los pone
## PartidoVisual según el evento actual (equipo + jugador_posicion).
var resaltado_local: String = ""
var resaltado_visitante: String = ""


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

	_dibujar_formacion(false, COLOR_LOCAL, resaltado_local)
	_dibujar_formacion(true, COLOR_VISITANTE, resaltado_visitante)


func _dibujar_formacion(invertido: bool, color: Color, resaltado_pos: String) -> void:
	for pos in FORMACION_SLOTS:
		var slots: Array = FORMACION_SLOTS[pos]
		for slot in slots:
			var x: float = (1.0 - slot["x"]) if invertido else slot["x"]
			var punto := Vector2(size.x * x, size.y * slot["y"])
			var radio: float = RADIO_RESALTADO if pos == resaltado_pos else RADIO_NORMAL
			draw_circle(punto, radio, color)
			draw_circle(punto, radio, Color.BLACK, false, 1.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
