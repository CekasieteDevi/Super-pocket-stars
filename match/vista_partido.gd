class_name VistaPartido
extends Control

## Reproduce los fotogramas que devuelve MotorEspacial. Es la única pieza
## de /match que sabe del motor: recibe la lista de fotogramas y la
## convierte en entidades para VistaCancha y Minimapa, que siguen sin
## saber nada de simulación.

signal terminado

## Ticks de juego por segundo real a x1. El motor simula a 0.25s por tick,
## así que 4 ticks/seg es TIEMPO REAL de fútbol: un pase tarda lo que
## tarda un pase.
const TICKS_POR_SEGUNDO := 4.0

## A 4 fotogramas por segundo hay que interpolar o se ve a saltos. Pero si
## dos fotogramas seguidos ponen a alguien más lejos que esto, es un salto
## de verdad (saque del medio tras un gol, un cambio, un tiro libre que
## reubica gente) y ahí se corta seco en vez de deslizarlo por la cancha.
const SALTO_MAXIMO_M := 12.0

var vista: VistaCancha
var minimapa: Minimapa

var fotogramas: Array = []
var posicion := 0.0
var velocidad := 1.0
var pausado := false

var color_local := Color.WHITE
var color_visitante := Color.WHITE
var _terminado := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista = VistaCancha.new()
	vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vista)
	minimapa = Minimapa.new()
	add_child(minimapa)
	set_process(true)


func iniciar(lista: Array, c_local: Color, c_visitante: Color, estado_cancha: String = "regular") -> void:
	fotogramas = lista
	color_local = c_local
	color_visitante = c_visitante
	vista.estado_cancha = estado_cancha
	posicion = 0.0
	pausado = false
	_terminado = false
	if not fotogramas.is_empty():
		_mostrar(0, 0.0)
		var f: Dictionary = fotogramas[0]
		vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), size)


## Salta al final SIN renderizar los fotogramas del medio: es un salto de
## índice, no una reproducción acelerada.
func saltar_al_final() -> void:
	if fotogramas.is_empty():
		_finalizar()
		return
	posicion = float(fotogramas.size() - 1)
	_mostrar(fotogramas.size() - 1, 0.0)
	_finalizar()


func _process(delta: float) -> void:
	if pausado or _terminado or fotogramas.is_empty():
		return
	posicion += delta * TICKS_POR_SEGUNDO * velocidad
	var idx: int = mini(int(posicion), fotogramas.size() - 1)
	_mostrar(idx, posicion - float(idx))
	_seguir_camara(idx, delta)
	if int(posicion) >= fotogramas.size() - 1:
		_finalizar()


func _finalizar() -> void:
	if _terminado:
		return
	_terminado = true
	terminado.emit()


## Arma las entidades del fotograma `idx` mezclado con el siguiente según
## `t`, y se las pasa a la cancha y al minimapa.
func _mostrar(idx: int, t: float) -> void:
	var a: Dictionary = fotogramas[idx]
	var b = fotogramas[idx + 1] if idx + 1 < fotogramas.size() else null
	var destino := {}
	if b != null and t > 0.0:
		for j in b["jugadores"]:
			destino[j["id"]] = j

	var ents: Array = []
	for j in a["jugadores"]:
		var p := Vector2(j["x"], j["y"])
		if not destino.is_empty() and destino.has(j["id"]):
			p = _mezclar(p, Vector2(destino[j["id"]]["x"], destino[j["id"]]["y"]), t)
		ents.append({
			"tipo": "jugador", "z": 0.0, "pos": p,
			"color": color_local if j["equipo_local"] else color_visitante,
		})

	var pa: Dictionary = a["pelota"]
	var pos_pelota := Vector2(pa["x"], pa["y"])
	var z: float = float(pa.get("z", 0.0))
	if b != null and t > 0.0:
		var pb: Dictionary = b["pelota"]
		pos_pelota = _mezclar(pos_pelota, Vector2(pb["x"], pb["y"]), t)
		z = lerpf(z, float(pb.get("z", 0.0)), t)
	ents.append({"tipo": "pelota", "color": Color.WHITE, "z": z, "pos": pos_pelota})

	vista.entidades = ents
	vista.queue_redraw()

	minimapa.position = size - minimapa.size - Vector2.ONE * Minimapa.MARGEN_PX
	minimapa.entidades = ents
	minimapa.encuadre = vista.camara.encuadre_metros(size)
	minimapa.queue_redraw()


static func _mezclar(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a if a.distance_squared_to(b) > SALTO_MAXIMO_M * SALTO_MAXIMO_M else a.lerp(b, t)


## La cámara sigue la pelota. La velocidad se estima con el fotograma
## siguiente, que es lo que le permite anticipar hacia dónde va la jugada.
func _seguir_camara(idx: int, delta: float) -> void:
	var pa: Dictionary = fotogramas[idx]["pelota"]
	var actual := Vector2(pa["x"], pa["y"])
	var vel := Vector2.ZERO
	if idx + 1 < fotogramas.size():
		var pb: Dictionary = fotogramas[idx + 1]["pelota"]
		var d := Vector2(pb["x"], pb["y"]) - actual
		if d.length() < SALTO_MAXIMO_M:
			vel = d / MotorEspacial.TICK_SEG
	var en_area: bool = absf(actual.x) > ProyeccionPartido.MEDIO_LARGO - 16.5
	vista.camara.fijar_encuadre(en_area, false)
	vista.camara.seguir(actual, vel, size, delta)
