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

## Ticks de juego que se muestran por segundo real, a velocidad x1. El
## motor simula a 0.25s por tick, o sea 21.600 ticks por partido: a 90
## ticks/seg reales el partido completo dura 4 minutos, ~2 por tiempo,
## que es el ritmo que acordamos.
const TICKS_POR_SEGUNDO := 90.0

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

	for etiqueta in ["x1", "x2", "x4"]:
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
	posicion = 0.0
	pausado = false
	terminado_emitido = false
	boton_pausa.text = "Pausa"
	label_evento.text = "Arranca el partido..."
	label_minuto.text = "Min 0"
	_refrescar_marcador(0, 0)
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
	cancha.mostrar(f)
	label_minuto.text = "Min %d" % int(f["minuto"])
	var g: Dictionary = f["goles"]
	_refrescar_marcador(int(g["home"]), int(g["away"]))

	if int(posicion) >= fotogramas.size() - 1:
		_finalizar()


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
			return "%s: le quitan la pelota a %s" % [evento["equipo"], pos]
		"tarjeta":
			if evento["resultado"] == "amarilla":
				return "%s: TARJETA AMARILLA para %s" % [evento["equipo"], pos]
			return "%s: TARJETA ROJA para %s%s" % [evento["equipo"], pos, " (doble amarilla)" if evento["resultado"] == "roja_doble_amarilla" else ""]
		"cambio":
			return "%s: CAMBIO — sale %s (%s)" % [evento["equipo"], pos, evento["resultado"]]
	# Los pases son la enorme mayoría de los eventos: narrarlos todos
	# taparía el relato de lo que importa.
	return ""
