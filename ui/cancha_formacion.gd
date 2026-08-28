class_name CanchaFormacion
extends Control

## La cancha de la pantalla de Formación: dibuja el campo y para a los once
## titulares donde dice la formación elegida.
##
## Las posiciones salen de las MISMAS coordenadas que usa el motor
## (data/formaciones.json, metros con origen en el centro), así que lo que
## ves acá es literalmente dónde va a arrancar cada uno en el partido. Si
## se cambia una formación en el JSON, esta pantalla la refleja sola.

signal intercambio_pedido(id_origen: int, id_destino: int)

## Medidas reales de una cancha, para que el dibujo tenga las proporciones
## de una de verdad y las posiciones caigan donde corresponde.
const LARGO_M := 105.0
const ANCHO_M := 68.0
const AREA_LARGO_M := 16.5
const AREA_ANCHO_M := 40.3

var _equipo: Team = null
var _cubos: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(700, 440)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func mostrar(equipo: Team) -> void:
	_equipo = equipo
	for c in _cubos:
		c.queue_free()
	_cubos.clear()

	var slots: Array = Formaciones.slots(equipo.formacion)
	for i in range(min(slots.size(), equipo.jugadores.size())):
		var cubo := CuboJugador.crear(
			equipo.jugadores[i], str(slots[i]["rol"]), equipo, false)
		cubo.intercambio_pedido.connect(func(a, b): intercambio_pedido.emit(a, b))
		add_child(cubo)
		_cubos.append(cubo)
	queue_redraw()
	_acomodar()


func _notification(que: int) -> void:
	if que == NOTIFICATION_RESIZED:
		_acomodar()
		queue_redraw()


## Mete el rectángulo de la cancha adentro del control conservando la
## proporción: estirada, las posiciones dejarían de significar lo que
## significan en el partido.
func _rect_cancha() -> Rect2:
	var disponible := size
	if disponible.x <= 0.0 or disponible.y <= 0.0:
		return Rect2()
	var escala: float = minf(disponible.x / LARGO_M, disponible.y / ANCHO_M)
	var w := LARGO_M * escala
	var h := ANCHO_M * escala
	return Rect2((disponible.x - w) * 0.5, (disponible.y - h) * 0.5, w, h)


## De metros del motor a píxeles de la pantalla.
func _a_pantalla(metros: Vector2) -> Vector2:
	var r := _rect_cancha()
	return Vector2(
		r.position.x + (metros.x + LARGO_M * 0.5) / LARGO_M * r.size.x,
		r.position.y + (metros.y + ANCHO_M * 0.5) / ANCHO_M * r.size.y)


func _acomodar() -> void:
	if _equipo == null:
		return
	var slots: Array = Formaciones.slots(_equipo.formacion)
	for i in range(_cubos.size()):
		if i >= slots.size():
			continue
		var base: Vector2 = slots[i]["base"]
		var centro := _a_pantalla(base)
		var cubo: CuboJugador = _cubos[i]
		cubo.position = centro - Vector2(CuboJugador.ANCHO, CuboJugador.ALTO) * 0.5


func _draw() -> void:
	var r := _rect_cancha()
	if r.size.x <= 0.0:
		return
	var cesped := Color("#1b3327")
	var linea := Color(1, 1, 1, 0.28)
	draw_rect(r, cesped, true)

	# Franjas de corte, como una cancha de verdad. Sutiles: son fondo, no
	# tienen que competir con los jugadores.
	var franjas := 10
	for i in range(franjas):
		if i % 2 == 0:
			continue
		var ancho_franja := r.size.x / float(franjas)
		draw_rect(Rect2(r.position.x + i * ancho_franja, r.position.y,
			ancho_franja, r.size.y), Color(1, 1, 1, 0.022), true)

	draw_rect(r, linea, false, 2.0)
	# Línea de mitad y círculo central.
	var medio := r.position.x + r.size.x * 0.5
	draw_line(Vector2(medio, r.position.y), Vector2(medio, r.position.y + r.size.y), linea, 2.0)
	draw_arc(Vector2(medio, r.position.y + r.size.y * 0.5),
		9.15 / LARGO_M * r.size.x, 0.0, TAU, 48, linea, 2.0)

	# Las dos áreas.
	var area_w := AREA_LARGO_M / LARGO_M * r.size.x
	var area_h := AREA_ANCHO_M / ANCHO_M * r.size.y
	var area_y := r.position.y + (r.size.y - area_h) * 0.5
	draw_rect(Rect2(r.position.x, area_y, area_w, area_h), linea, false, 2.0)
	draw_rect(Rect2(r.position.x + r.size.x - area_w, area_y, area_w, area_h), linea, false, 2.0)

	# Hacia dónde se ataca: sin esto no se entiende por qué el arquero está
	# a la izquierda.
	var flecha_y := r.position.y + r.size.y - 16.0
	draw_line(Vector2(medio - 40, flecha_y), Vector2(medio + 40, flecha_y), Color(1, 1, 1, 0.18), 2.0)
	draw_line(Vector2(medio + 40, flecha_y), Vector2(medio + 30, flecha_y - 6), Color(1, 1, 1, 0.18), 2.0)
	draw_line(Vector2(medio + 40, flecha_y), Vector2(medio + 30, flecha_y + 6), Color(1, 1, 1, 0.18), 2.0)
