class_name PrototipoVista
extends Control

## Prototipo de la vista nueva con DATOS FALSOS — no toca el motor.
## Existe solo para aprobar cómo se ve la etapa 1 (proyección, cámara,
## cancha, sprites con sombra) antes de conectar nada.
##
## Los 22 jugadores se mueven con una coreografía inventada y la pelota
## recorre el campo con altura, para poder juzgar el Y-sort, las sombras y
## el seguimiento de cámara.

const COLOR_LOCAL := Color(0.93, 0.74, 0.16)
const COLOR_VISITANTE := Color(0.30, 0.56, 0.92)

var vista: VistaCancha
var _t := 0.0
var _base_local: Array = []
var _base_visitante: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista = VistaCancha.new()
	vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vista)

	# Formación 4-3-3 espejada, en metros.
	var plantilla := [
		Vector2(-48, 0), Vector2(-34, -12), Vector2(-34, 12),
		Vector2(-30, -26), Vector2(-30, 26), Vector2(-14, -10),
		Vector2(-14, 10), Vector2(-4, 0), Vector2(8, -22),
		Vector2(8, 22), Vector2(16, 0),
	]
	for p in plantilla:
		_base_local.append(p)
		_base_visitante.append(Vector2(-p.x, p.y))

	vista.camara.saltar_a(Vector2.ZERO, size)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta

	# Pelota: recorre la cancha en ocho y pega saltos, para ver la altura.
	var pelota := Vector2(sin(_t * 0.45) * 38.0, sin(_t * 0.9) * 20.0)
	var z: float = maxf(0.0, sin(_t * 1.7)) * 7.0
	var vel := Vector2(cos(_t * 0.45) * 38.0 * 0.45, cos(_t * 0.9) * 20.0 * 0.9)

	var ents: Array = []
	for i in range(_base_local.size()):
		ents.append({
			"tipo": "jugador", "color": COLOR_LOCAL, "z": 0.0,
			"pos": _base_local[i] + _vaiven(i, 1.0) + (pelota - _base_local[i]) * 0.12,
		})
		ents.append({
			"tipo": "jugador", "color": COLOR_VISITANTE, "z": 0.0,
			"pos": _base_visitante[i] + _vaiven(i, -1.0) + (pelota - _base_visitante[i]) * 0.12,
		})
	ents.append({"tipo": "pelota", "color": Color.WHITE, "z": z, "pos": pelota})

	vista.entidades = ents
	vista.camara.fijar_encuadre(absf(pelota.x) > 36.0, false)
	vista.camara.seguir(pelota, vel, size, delta)
	vista.queue_redraw()


func _vaiven(i: int, signo: float) -> Vector2:
	var f := float(i) * 0.7
	return Vector2(sin(_t * 0.8 + f) * 2.5 * signo, cos(_t * 0.6 + f) * 2.0)
