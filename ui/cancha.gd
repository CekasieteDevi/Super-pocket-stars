class_name Cancha
extends Control

## Cancha del partido animado. Desde el motor espacial
## (docs/motor_espacial.md) esto NO calcula ni aproxima posiciones: recibe
## un fotograma del motor —con las coordenadas reales en metros de los 22
## jugadores y la pelota— y lo dibuja. Toda la maquinaria anterior de
## formación fija + "empuje" del bloque desapareció: existía solo porque
## el motor no tenía coordenadas y había que adivinar dónde estaba cada
## uno.

const COLOR_LOCAL := Color(0.95, 0.75, 0.15)
const COLOR_VISITANTE := Color(0.35, 0.65, 0.95)
const COLOR_CESPED_CLARO := Color(0.14, 0.5, 0.16)
const COLOR_CESPED_OSCURO := Color(0.11, 0.44, 0.13)
const BANDAS_CESPED := 10
const ANCHO_SPRITE := 18.0
const ANCHO_SPRITE_CON_PELOTA := 26.0

## Medidas reglamentarias que usa el motor, para convertir metros a
## píxeles (MotorEspacial.LARGO / ANCHO).
const LARGO_M := 105.0
const ANCHO_M := 68.0

var fotograma: Dictionary = {}

var _tex_local: ImageTexture
var _tex_visitante: ImageTexture
var _tex_pelota: ImageTexture


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_local = PixelArt.jugador_textura(COLOR_LOCAL)
	_tex_visitante = PixelArt.jugador_textura(COLOR_VISITANTE)
	_tex_pelota = PixelArt.pelota_textura()


func mostrar(f: Dictionary) -> void:
	fotograma = f
	queue_redraw()


## Metros del motor (origen en el centro de la cancha) a píxeles del
## Control, manteniendo la proporción y centrando lo que sobre.
func _a_pantalla(x: float, y: float) -> Vector2:
	var escala: float = minf(size.x / LARGO_M, size.y / ANCHO_M)
	return Vector2(size.x * 0.5 + x * escala, size.y * 0.5 + y * escala)


func _draw() -> void:
	var escala: float = minf(size.x / LARGO_M, size.y / ANCHO_M)
	var origen := _a_pantalla(-LARGO_M / 2.0, -ANCHO_M / 2.0)
	var medidas := Vector2(LARGO_M * escala, ANCHO_M * escala)

	_dibujar_cesped(origen, medidas)
	draw_rect(Rect2(origen, medidas), Color.WHITE, false, 2.0)
	draw_line(_a_pantalla(0, -ANCHO_M / 2.0), _a_pantalla(0, ANCHO_M / 2.0), Color.WHITE, 2.0)
	draw_arc(_a_pantalla(0, 0), 9.15 * escala, 0, TAU, 32, Color.WHITE, 2.0)

	# Áreas grandes reglamentarias: 16.5m de fondo, 40.32m de ancho.
	var area := Vector2(16.5 * escala, 40.32 * escala)
	draw_rect(Rect2(_a_pantalla(-LARGO_M / 2.0, -20.16), area), Color.WHITE, false, 2.0)
	draw_rect(Rect2(_a_pantalla(LARGO_M / 2.0 - 16.5, -20.16), area), Color.WHITE, false, 2.0)

	if fotograma.is_empty():
		return

	var poseedor: int = int(fotograma["pelota"].get("poseedor_id", -1))
	for j in fotograma["jugadores"]:
		var textura: ImageTexture = _tex_local if j["equipo_local"] else _tex_visitante
		var con_pelota: bool = int(j["id"]) == poseedor
		var ancho: float = ANCHO_SPRITE_CON_PELOTA if con_pelota else ANCHO_SPRITE
		var alto: float = ancho * (textura.get_height() / float(textura.get_width()))
		var punto := _a_pantalla(j["x"], j["y"])
		draw_texture_rect(textura, Rect2(punto - Vector2(ancho, alto) / 2.0, Vector2(ancho, alto)), false)

	var b: Dictionary = fotograma["pelota"]
	var pelota_px := _a_pantalla(b["x"], b["y"])
	draw_texture_rect(_tex_pelota, Rect2(pelota_px - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), false)


func _dibujar_cesped(origen: Vector2, medidas: Vector2) -> void:
	var ancho_banda := medidas.x / float(BANDAS_CESPED)
	for i in range(BANDAS_CESPED):
		var color := COLOR_CESPED_CLARO if i % 2 == 0 else COLOR_CESPED_OSCURO
		draw_rect(Rect2(origen + Vector2(i * ancho_banda, 0), Vector2(ancho_banda + 1.0, medidas.y)), color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
