class_name PartidoVisual
extends Control

## Visualización del partido propio. Desde el motor espacial
## (docs/motor_espacial.md) reproduce los FOTOGRAMAS que devuelve
## MotorEspacial: las posiciones reales de los 22 jugadores y de la pelota,
## tick a tick. Ya no infiere nada — antes tenía que adivinar dónde estaba
## cada uno a partir del tipo de evento, porque el motor no manejaba
## coordenadas.
##
## El relato sale del campo "evento" de cada fotograma, que trae el evento
## semántico ocurrido en ESE tick (o null), así que el comentario y el
## marcador caen en el momento exacto.

signal terminado

## Ticks de juego por segundo real a velocidad x1. El motor simula a 0.25s
## por tick, asi que 4 ticks/seg es TIEMPO REAL de futbol: un pase tarda lo
## que tarda un pase, y se entiende quien tiene la pelota y que hace.
##
## Antes esto valia 90 (todo el partido en 4 minutos), o sea 22 veces la
## velocidad real: pasaban diez cosas por segundo y era imposible seguir la
## jugada. Un partido entero a x1 dura los 90 minutos de verdad — para eso
## estan los multiplicadores y el boton de saltar al resultado.
const TICKS_POR_SEGUNDO := 4.0

## A 4 ticks/seg las posiciones se actualizan solo 4 veces por segundo: sin
## interpolar entre fotograma y fotograma se veria a saltos. Si dos
## fotogramas seguidos ponen a alguien mas lejos que esto, es un salto de
## verdad (saque del medio despues de un gol, cambio) y ahi NO se
## interpola, se corta seco.
const SALTO_MAXIMO_M := 12.0

## Se reproduce el partido COMPLETO, sin cortes ni resúmenes: el motor ya
## simula un partido de 480 ticks por tiempo (MotorEspacial.TICKS_POR_MITAD),
## o sea 2 minutos reales a 4 fotogramas por segundo. No hace falta saltear
## nada porque no sobra nada.

var fotogramas: Array = []
var posicion: float = 0.0
var velocidad: float = 1.0
var pausado: bool = false
var terminado_emitido: bool = false

var equipo_local: String
var equipo_visitante: String

var cancha: Cancha
var label_marcador: Label
var label_minuto: Label
var label_evento: Label
var boton_pausa: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)

	label_marcador = Label.new()
	label_marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_marcador.add_theme_font_size_override("font_size", 26)
	raiz.add_child(label_marcador)

	label_minuto = Label.new()
	label_minuto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(label_minuto)

	cancha = Cancha.new()
	cancha.custom_minimum_size = Vector2(0, 260)
	cancha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(cancha)

	label_evento = Label.new()
	label_evento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(label_evento)

	var barra := HBoxContainer.new()
	barra.alignment = BoxContainer.ALIGNMENT_CENTER
	raiz.add_child(barra)

	# x1 es tiempo real de fútbol; los multiplicadores altos estan para
	# pasar rapido los tramos en que no pasa nada.
	for etiqueta in ["x1", "x2", "x4", "x8", "x16"]:
		var btn := Button.new()
		btn.text = etiqueta
		var v := float(etiqueta.substr(1))
		btn.pressed.connect(func(): velocidad = v)
		barra.add_child(btn)

	boton_pausa = Button.new()
	boton_pausa.text = "Pausa"
	boton_pausa.pressed.connect(_toggle_pausa)
	barra.add_child(boton_pausa)

	var btn_saltar := Button.new()
	btn_saltar.text = "Saltar al resultado"
	btn_saltar.pressed.connect(_saltar)
	barra.add_child(btn_saltar)

	set_process(true)


func iniciar(local: String, visitante: String, lista_fotogramas: Array) -> void:
	equipo_local = local
	equipo_visitante = visitante
	fotogramas = lista_fotogramas
	pausado = false
	terminado_emitido = false
	boton_pausa.text = "Pausa"
	label_evento.text = "Arranca el partido..."
	label_minuto.text = "Min 0"
	_refrescar_marcador(0, 0)
	posicion = 0.0
	if not fotogramas.is_empty():
		cancha.mostrar(fotogramas[0])


func _process(delta: float) -> void:
	if pausado or fotogramas.is_empty() or terminado_emitido:
		return

	var desde: int = int(posicion)
	posicion += delta * TICKS_POR_SEGUNDO * velocidad
	var hasta: int = mini(int(posicion), fotogramas.size() - 1)

	# Entre un frame de pantalla y el siguiente pasan varios ticks de
	# juego: hay que barrerlos para no perderse el gol que ocurrió en el
	# medio, aunque solo se dibuje el último.
	for i in range(desde + 1, hasta + 1):
		var ev = fotogramas[i].get("evento", null)
		if ev != null:
			var texto := _texto_evento(ev)
			if texto != "":
				label_evento.text = texto

	var f: Dictionary = fotogramas[hasta]
	cancha.mostrar(_interpolado(hasta, posicion - float(hasta)))
	label_minuto.text = "Min %d" % int(f["minuto"])
	var g: Dictionary = f["goles"]
	_refrescar_marcador(int(g["home"]), int(g["away"]))

	if int(posicion) >= fotogramas.size() - 1:
		_finalizar()


## Mezcla el fotograma `idx` con el siguiente segun la fraccion `t`, para
## que a velocidad real (4 fotogramas por segundo) el movimiento se vea
## continuo y no a saltos.
func _interpolado(idx: int, t: float) -> Dictionary:
	var a: Dictionary = fotogramas[idx]
	if idx + 1 >= fotogramas.size() or t <= 0.0:
		return a
	var b: Dictionary = fotogramas[idx + 1]

	var destino := {}
	for j in b["jugadores"]:
		destino[j["id"]] = j

	var jugadores := []
	for j in a["jugadores"]:
		var d = destino.get(j["id"], null)
		var x: float = j["x"]
		var y: float = j["y"]
		if d != null:
			var dx: float = d["x"] - x
			var dy: float = d["y"] - y
			if dx * dx + dy * dy <= SALTO_MAXIMO_M * SALTO_MAXIMO_M:
				x += dx * t
				y += dy * t
		jugadores.append({
			"id": j["id"], "equipo_local": j["equipo_local"], "rol": j["rol"],
			"x": x, "y": y,
		})

	var pa: Dictionary = a["pelota"]
	var pb: Dictionary = b["pelota"]
	var bx: float = pa["x"]
	var by: float = pa["y"]
	var pdx: float = pb["x"] - bx
	var pdy: float = pb["y"] - by
	if pdx * pdx + pdy * pdy <= SALTO_MAXIMO_M * SALTO_MAXIMO_M:
		bx += pdx * t
		by += pdy * t

	return {
		"tick": a["tick"], "minuto": a["minuto"], "goles": a["goles"],
		"jugadores": jugadores,
		"pelota": {"x": bx, "y": by, "poseedor_id": pa["poseedor_id"]},
	}


func _refrescar_marcador(gl: int, gv: int) -> void:
	label_marcador.text = "%s   %d - %d   %s" % [equipo_local, gl, gv, equipo_visitante]


func _toggle_pausa() -> void:
	pausado = not pausado
	boton_pausa.text = "Reanudar" if pausado else "Pausa"


func _saltar() -> void:
	if fotogramas.is_empty():
		_finalizar()
		return
	posicion = fotogramas.size() - 1
	var f: Dictionary = fotogramas[fotogramas.size() - 1]
	cancha.mostrar(f)
	label_minuto.text = "Min %d" % int(f["minuto"])
	var g: Dictionary = f["goles"]
	_refrescar_marcador(int(g["home"]), int(g["away"]))
	_finalizar()


func _finalizar() -> void:
	if terminado_emitido:
		return
	terminado_emitido = true
	label_evento.text = "Final del partido."
	terminado.emit()


func _texto_evento(evento: Dictionary) -> String:
	var pos: String = evento["jugador_posicion"]
	match evento["tipo"]:
		"tiro":
			return "%s: remata %s... %s" % [evento["equipo"], pos, evento["resultado"]]
		"tiro_puerta":
			return "%s: REMATE de %s... %s" % [evento["equipo"], pos, "¡GOOOL!" if evento["resultado"] == "gol" else "ataja el arquero"]
		"gambeta":
			if evento["resultado"] == "pasa":
				return "%s: %s se saca uno de encima" % [evento["equipo"], pos]
			return "%s: le quitan la pelota a %s" % [evento["equipo"], pos]
		"tarjeta":
			if evento["resultado"] == "amarilla":
				return "%s: TARJETA AMARILLA para %s" % [evento["equipo"], pos]
			return "%s: TARJETA ROJA para %s%s" % [evento["equipo"], pos, " (doble amarilla)" if evento["resultado"] == "roja_doble_amarilla" else ""]
		"cambio":
			return "%s: CAMBIO — sale %s (%s)" % [evento["equipo"], pos, evento["resultado"]]
		"centro":
			match evento["resultado"]:
				"gana":
					return "%s: centro y la gana de arriba %s" % [evento["equipo"], pos]
				"descuelga":
					return "%s: centro, pero sale el arquero y la descuelga" % evento["equipo"]
				_:
					return "%s: centro al área, despeja %s" % [evento["equipo"], pos]
		"saque_arco":
			return "%s: saque de arco" % evento["equipo"]
		"corner":
			return "%s: CÓRNER" % evento["equipo"]
		"lateral":
			return "%s: saca de lateral" % evento["equipo"]
	# Los pases son la enorme mayoría de los eventos: narrarlos todos
	# taparía el relato de lo que importa.
	return ""
