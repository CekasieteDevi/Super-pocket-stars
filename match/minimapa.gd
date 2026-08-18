class_name Minimapa
extends Control

## Cancha entera en chico, abajo a la derecha. NO es decorativo: la cámara
## muestra alrededor de un cuarto de la cancha, así que sin esto el jugador
## no tiene forma de saber dónde está la jugada ni cómo están parados los
## equipos. Es lo que hace viable el zoom cercano.
##
## Dibuja en proyección plana a propósito: acá lo que importa es leer de un
## vistazo, no que se vea lindo.

const ANCHO_PX := 190.0
const MARGEN_PX := 14.0
const COLOR_FONDO := Color(0.08, 0.16, 0.09, 0.82)
const COLOR_BORDE := Color(1, 1, 1, 0.35)
const COLOR_LINEA := Color(1, 1, 1, 0.22)
const COLOR_PELOTA := Color.WHITE
const COLOR_ENCUADRE := Color(1, 1, 1, 0.5)
const RADIO_JUGADOR := 2.6

## Mismo formato que VistaCancha.entidades.
var entidades: Array = []
## Rectángulo de cancha que la cámara está mostrando, en metros.
var encuadre := Rect2()


func _ready() -> void:
	var alto := ANCHO_PX * (ProyeccionPartido.ANCHO / ProyeccionPartido.LARGO)
	custom_minimum_size = Vector2(ANCHO_PX, alto)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Metros de cancha a píxeles del minimapa, plano y directo.
func _m(x: float, y: float) -> Vector2:
	return Vector2(
		(x + ProyeccionPartido.MEDIO_LARGO) / ProyeccionPartido.LARGO * size.x,
		(y + ProyeccionPartido.MEDIO_ANCHO) / ProyeccionPartido.ANCHO * size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_FONDO)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BORDE, false, 1.5)
	draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), COLOR_LINEA, 1.0)
	draw_arc(size * 0.5, size.y * 0.13, 0, TAU, 20, COLOR_LINEA, 1.0)

	var L := ProyeccionPartido.MEDIO_LARGO
	for lado in [-1.0, 1.0]:
		var a := _m(lado * L, -20.16)
		var b := _m(lado * (L - 16.5), 20.16)
		draw_rect(Rect2(Vector2(minf(a.x, b.x), a.y), (b - a).abs()), COLOR_LINEA, false, 1.0)

	# Qué parte de la cancha está viendo la cámara. Se recorta al panel:
	# con la cámara en un borde el encuadre se sale de la cancha, y sin
	# recortar el recuadro se dibujaba por fuera del minimapa.
	if encuadre.size.x > 0.0:
		var e0 := _m(encuadre.position.x, encuadre.position.y)
		var e1 := _m(encuadre.end.x, encuadre.end.y)
		var r := Rect2(e0, e1 - e0).intersection(Rect2(Vector2.ZERO, size))
		if r.size.x > 0.0 and r.size.y > 0.0:
			draw_rect(r, COLOR_ENCUADRE, false, 1.5)

	for ent in entidades:
		if ent["tipo"] == "pelota":
			continue
		draw_circle(_m(ent["pos"].x, ent["pos"].y), RADIO_JUGADOR, ent["color"])
	for ent in entidades:
		if ent["tipo"] == "pelota":
			var p := _m(ent["pos"].x, ent["pos"].y)
			draw_circle(p, RADIO_JUGADOR * 0.9, Color(0, 0, 0, 0.6))
			draw_circle(p, RADIO_JUGADOR * 0.65, COLOR_PELOTA)
