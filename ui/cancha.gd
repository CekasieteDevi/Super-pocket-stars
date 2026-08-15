class_name Cancha
extends Control

## Cancha dibujada por código — Fase 8, pulida con 22 posiciones fijas y
## sprites pixel-art (PixelArt.jugador_textura). Sin movimiento real de
## jugadores: el motor sigue sin calcular posiciones x/y por jugador
## durante el partido, solo zona de la jugada (armado/último tercio) y la
## posición del que participa. Lo que se dibuja acá es una FORMACIÓN FIJA
## por equipo (11 sprites cada uno, según FORMACION_SLOTS) para que la
## cancha se sienta poblada — el que participa de la jugada actual se
## resalta más grande, en vez de mover los 22 de verdad.

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
const COLOR_CESPED_CLARO := Color(0.14, 0.5, 0.16)
const COLOR_CESPED_OSCURO := Color(0.11, 0.44, 0.13)
const BANDAS_CESPED := 10
const ANCHO_SPRITE_NORMAL := 20.0
const ANCHO_SPRITE_RESALTADO := 30.0

## Posición cuyo sprite se dibuja más grande — "" si ninguna. Los pone
## PartidoVisual según el evento actual (equipo + jugador_posicion).
var resaltado_local: String = ""
var resaltado_visitante: String = ""

var _tex_local: ImageTexture
var _tex_visitante: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_local = PixelArt.jugador_textura(COLOR_LOCAL)
	_tex_visitante = PixelArt.jugador_textura(COLOR_VISITANTE)


func _draw() -> void:
	var w := size.x
	var h := size.y

	_dibujar_cesped(w, h)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE, false, 2.0)
	draw_line(Vector2(w / 2.0, 0), Vector2(w / 2.0, h), Color.WHITE, 2.0)
	draw_arc(Vector2(w / 2.0, h / 2.0), h * 0.16, 0, TAU, 32, Color.WHITE, 2.0)

	var area_w := w * 0.12
	var area_h := h * 0.55
	draw_rect(Rect2(Vector2(0, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)
	draw_rect(Rect2(Vector2(w - area_w, (h - area_h) / 2.0), Vector2(area_w, area_h)), Color.WHITE, false, 2.0)

	_dibujar_formacion(false, _tex_local, resaltado_local)
	_dibujar_formacion(true, _tex_visitante, resaltado_visitante)


func _dibujar_cesped(w: float, h: float) -> void:
	var ancho_banda := w / float(BANDAS_CESPED)
	for i in range(BANDAS_CESPED):
		var color := COLOR_CESPED_CLARO if i % 2 == 0 else COLOR_CESPED_OSCURO
		draw_rect(Rect2(Vector2(i * ancho_banda, 0), Vector2(ancho_banda + 1.0, h)), color)


func _dibujar_formacion(invertido: bool, textura: ImageTexture, resaltado_pos: String) -> void:
	for pos in FORMACION_SLOTS:
		var slots: Array = FORMACION_SLOTS[pos]
		for slot in slots:
			var x: float = (1.0 - slot["x"]) if invertido else slot["x"]
			var punto := Vector2(size.x * x, size.y * slot["y"])
			var resaltado: bool = pos == resaltado_pos
			var ancho: float = ANCHO_SPRITE_RESALTADO if resaltado else ANCHO_SPRITE_NORMAL
			var alto: float = ancho * (textura.get_height() / float(textura.get_width()))
			var rect := Rect2(punto - Vector2(ancho, alto) / 2.0, Vector2(ancho, alto))
			draw_texture_rect(textura, rect, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
