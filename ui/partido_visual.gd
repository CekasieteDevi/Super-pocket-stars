class_name PartidoVisual
extends Control

## Visualización de partido — Fase 8 (GDD roadmap §13, §11), pulida con
## formaciones fijas (Cancha.FORMACION_SLOTS). Reproduce la lista de
## "eventos" estructurados que ya devuelve MatchEngine.simular() a un
## ritmo controlable: 22 puntos en cancha (11 por equipo, en su posición
## de formación) y una pelota que se mueve en X e Y según la zona de la
## jugada y el carril de la posición que participa — el punto del que
## está en juego se agranda.
##
## Sigue siendo abstracto: el motor no calcula movimiento real de
## jugadores durante el partido (solo zona de la jugada + la posición del
## que participa), así que los 22 puntos son una formación fija, no 22
## muñequitos corriendo. Pixel art / arte real sigue pendiente.

signal terminado

const INTERVALO_BASE := 0.12  # segundos entre eventos a velocidad x1

var eventos: Array = []
var indice: int = 0
var velocidad: float = 1.0
var pausado: bool = false

var equipo_local: String
var equipo_visitante: String
var goles_local: int = 0
var goles_visitante: int = 0

var cancha: Cancha
var pelota: Pelota
var label_marcador: Label
var label_minuto: Label
var label_evento: Label
var boton_pausa: Button
var timer: Timer


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

	var contenedor_cancha := Control.new()
	contenedor_cancha.custom_minimum_size = Vector2(0, 260)
	contenedor_cancha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(contenedor_cancha)

	cancha = Cancha.new()
	cancha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor_cancha.add_child(cancha)

	pelota = Pelota.new()
	pelota.size = Vector2(16, 16)
	contenedor_cancha.add_child(pelota)

	label_evento = Label.new()
	label_evento.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(label_evento)

	var barra_controles := HBoxContainer.new()
	barra_controles.alignment = BoxContainer.ALIGNMENT_CENTER
	raiz.add_child(barra_controles)

	for etiqueta in ["x1", "x2", "x4"]:
		var btn := Button.new()
		btn.text = etiqueta
		var v := float(etiqueta.substr(1))
		btn.pressed.connect(func(): _cambiar_velocidad(v))
		barra_controles.add_child(btn)

	boton_pausa = Button.new()
	boton_pausa.text = "Pausa"
	boton_pausa.pressed.connect(_toggle_pausa)
	barra_controles.add_child(boton_pausa)

	var btn_saltar := Button.new()
	btn_saltar.text = "Saltar al resultado"
	btn_saltar.pressed.connect(_saltar)
	barra_controles.add_child(btn_saltar)

	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_procesar_siguiente)
	add_child(timer)


func iniciar(local: String, visitante: String, lista_eventos: Array) -> void:
	equipo_local = local
	equipo_visitante = visitante
	eventos = lista_eventos
	goles_local = 0
	goles_visitante = 0
	indice = 0
	pausado = false
	boton_pausa.text = "Pausa"
	label_evento.text = "Arranca el partido..."
	label_minuto.text = "Min 0"
	cancha.resaltado_local = ""
	cancha.resaltado_visitante = ""
	cancha.queue_redraw()
	_refrescar_marcador()
	_mover_pelota_instant(Vector2(0.5, 0.5))
	_procesar_siguiente()


func _refrescar_marcador() -> void:
	label_marcador.text = "%s   %d - %d   %s" % [equipo_local, goles_local, goles_visitante, equipo_visitante]


func _cambiar_velocidad(v: float) -> void:
	velocidad = v


func _toggle_pausa() -> void:
	pausado = not pausado
	boton_pausa.text = "Reanudar" if pausado else "Pausa"
	if not pausado and indice < eventos.size():
		_procesar_siguiente()


func _saltar() -> void:
	while indice < eventos.size():
		_aplicar_evento(eventos[indice])
		indice += 1
	timer.stop()
	_mover_pelota_instant(Vector2(0.5, 0.5))
	label_evento.text = "Final del partido."
	terminado.emit()


func _procesar_siguiente() -> void:
	if pausado:
		return
	if indice >= eventos.size():
		label_evento.text = "Final del partido."
		terminado.emit()
		return

	var evento: Dictionary = eventos[indice]
	_aplicar_evento(evento)
	indice += 1
	timer.wait_time = max(0.01, INTERVALO_BASE / velocidad)
	timer.start()


func _aplicar_evento(evento: Dictionary) -> void:
	label_minuto.text = "Min %d" % evento["minuto"]
	label_evento.text = _texto_evento(evento)

	var es_local: bool = evento["equipo"] == equipo_local
	if es_local:
		cancha.resaltado_local = evento["jugador_posicion"]
		cancha.resaltado_visitante = ""
	else:
		cancha.resaltado_visitante = evento["jugador_posicion"]
		cancha.resaltado_local = ""
	cancha.queue_redraw()

	_mover_pelota(_posicion(evento))

	if evento["resultado"] == "gol":
		if evento["equipo"] == equipo_local:
			goles_local += 1
		else:
			goles_visitante += 1
		_refrescar_marcador()


## Sin coordenadas x/y por jugador de verdad, se aproxima la posición de la
## pelota con la zona de la jugada para X ("pase"/"tarjeta" = zona de
## armado del equipo que participa, el resto = último tercio cerca del
## arco rival) y con el carril típico de la posición para Y (Cancha.
## FORMACION_SLOTS — un LAT/EXT tira por una punta al azar, el resto va
## centrado).
func _posicion(evento: Dictionary) -> Vector2:
	return Vector2(_posicion_x(evento), _posicion_y(evento))


func _posicion_x(evento: Dictionary) -> float:
	var ataca_local: bool = evento["equipo"] == equipo_local
	if evento["tipo"] == "pase" or evento["tipo"] == "tarjeta":
		return 0.35 if ataca_local else 0.65
	return 0.85 if ataca_local else 0.15


func _posicion_y(evento: Dictionary) -> float:
	var slots: Array = Cancha.FORMACION_SLOTS.get(evento["jugador_posicion"], [{"y": 0.5}])
	var slot: Dictionary = slots[randi() % slots.size()]
	return slot["y"]


func _mover_pelota(normalizado: Vector2) -> void:
	var destino := _punto_cancha(normalizado)
	var tween := create_tween()
	tween.tween_property(pelota, "position", destino, max(0.02, (INTERVALO_BASE / velocidad) * 0.85))


func _mover_pelota_instant(normalizado: Vector2) -> void:
	pelota.position = _punto_cancha(normalizado)


func _punto_cancha(normalizado: Vector2) -> Vector2:
	var ancho: float = cancha.size.x
	var alto: float = cancha.size.y
	return Vector2(ancho * normalizado.x - pelota.size.x / 2.0, alto * normalizado.y - pelota.size.y / 2.0)


func _texto_evento(evento: Dictionary) -> String:
	var pos: String = evento["jugador_posicion"]
	match evento["tipo"]:
		"pase":
			return "%s: %s intenta el pase... %s" % [evento["equipo"], pos, "avanza" if evento["resultado"] == "avanza" else "pierde la pelota"]
		"gambeta":
			return "%s: %s encara... %s" % [evento["equipo"], pos, "y remata" if evento["resultado"] == "tira" else "pierde la pelota"]
		"tiro":
			return "%s: tiro de %s... %s" % [evento["equipo"], pos, evento["resultado"]]
		"tiro_puerta":
			return "%s: TIRO A PUERTA de %s... %s" % [evento["equipo"], pos, "¡GOOOL!" if evento["resultado"] == "gol" else "atajada"]
		"rebote":
			return "%s: REBOTE, remata %s... %s" % [evento["equipo"], pos, "¡GOOOL!" if evento["resultado"] == "gol" else "atajada"]
		"tarjeta":
			if evento["resultado"] == "amarilla":
				return "%s: TARJETA AMARILLA para %s" % [evento["equipo"], pos]
			return "%s: TARJETA ROJA para %s%s" % [evento["equipo"], pos, " (doble amarilla)" if evento["resultado"] == "roja_doble_amarilla" else ""]
		"cambio":
			return "%s: CAMBIO — sale %s (%s)" % [evento["equipo"], pos, evento["resultado"]]
	return ""
