class_name PartidoVisual
extends Control

## Visualización de partido — Fase 8 (GDD roadmap §13, §11), pulida con
## formaciones dinámicas (Cancha.fijar_posesion) y sprites pixel-art.
## Reproduce la lista de "eventos" estructurados que ya devuelve
## MatchEngine.simular() a un ritmo controlable: la pelota se mueve al
## punto exacto del jugador que participa en cada evento (Cancha.punto_en,
## usando su carril de formación) y el bloque completo del equipo con la
## pelota empuja hacia adelante mientras el rival retrocede
## (Cancha.fijar_posesion), así los otros 21 sprites también reaccionan a
## la jugada en vez de quedarse fijos.
##
## Sigue siendo una aproximación: el motor no calcula posiciones x/y por
## jugador durante el partido, solo la zona de la jugada (armado/último
## tercio) y la posición del que participa — no hay 22 muñequitos con
## movimiento individual real, sino un bloque que se estira/compacta según
## esos dos datos.

## Cuán lejos del propio arco ocurre cada tipo de jugada (0 = propio arco,
## 1 = arco rival) — decide tanto dónde va la pelota como cuánto empuja el
## bloque del equipo (Cancha.fijar_posesion usa esto convertido a -1..1).
const ZONA_X_POR_TIPO := {
	"pase": 0.30, "tarjeta": 0.30, "gambeta": 0.55,
	"tiro": 0.85, "tiro_puerta": 0.88, "rebote": 0.88,
}

signal terminado

## A velocidad x1: MatchEngine.TICKS_POR_MITAD=90 duelos de armado/gambeta
## por tiempo, más los tiros que salgan de las gambetas ganadas — unos
## 100-130 eventos por tiempo en la práctica. A 1.0s/evento un tiempo dura
## cerca de los 2 minutos reales acordados; x2/x4 quedan para acelerar.
const INTERVALO_BASE := 1.0  # segundos entre eventos a velocidad x1

var eventos: Array = []
var indice: int = 0
var velocidad: float = 1.0
var pausado: bool = false

var equipo_local: String
var equipo_visitante: String
var estilo_local: String = ""
var estilo_visitante: String = ""
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


func iniciar(local: String, visitante: String, lista_eventos: Array, estilo_local_: String = "", estilo_visitante_: String = "") -> void:
	equipo_local = local
	equipo_visitante = visitante
	estilo_local = estilo_local_
	estilo_visitante = estilo_visitante_
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
	cancha.empuje_local = 0.0
	cancha.empuje_visitante = 0.0
	cancha._render_local.clear()
	cancha._render_visitante.clear()
	cancha.queue_redraw()
	_refrescar_marcador()
	_mover_pelota_instant(cancha.size / 2.0)
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
	_mover_pelota_instant(cancha.size / 2.0)
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
	# En un cambio no hay pelota en juego que mostrar: se deja la
	# formación normal, sin resaltar a nadie ni mover el bloque.
	if evento["tipo"] == "cambio":
		cancha.resaltado_local = ""
		cancha.resaltado_visitante = ""
		cancha.queue_redraw()
		return

	var zona_x: float = ZONA_X_POR_TIPO.get(evento["tipo"], 0.5)
	# El mismo punto que recibe la pelota es el que dibuja el sprite
	# agrandado (Cancha._dibujar_formacion), para que siempre coincidan.
	var punto := cancha.punto_en(zona_x, evento["jugador_posicion"], not es_local)
	if es_local:
		cancha.resaltado_local = evento["jugador_posicion"]
		cancha.punto_resaltado_local = punto
		cancha.resaltado_visitante = ""
	else:
		cancha.resaltado_visitante = evento["jugador_posicion"]
		cancha.punto_resaltado_visitante = punto
		cancha.resaltado_local = ""
	# El que defiende retrocede según SU propio estilo (Presión alta va a
	# buscar la pelota en vez de replegarse — ver Estilos.retroceso_sin_pelota).
	var estilo_defensor: String = estilo_visitante if es_local else estilo_local
	cancha.fijar_posesion(es_local, (zona_x - 0.5) * 2.0, Estilos.retroceso_sin_pelota(estilo_defensor))
	cancha.queue_redraw()
	_mover_pelota(punto)

	if evento["resultado"] == "gol":
		if evento["equipo"] == equipo_local:
			goles_local += 1
		else:
			goles_visitante += 1
		_refrescar_marcador()


func _mover_pelota(destino: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(pelota, "position", destino - pelota.size / 2.0, max(0.02, (INTERVALO_BASE / velocidad) * 0.85))


func _mover_pelota_instant(destino: Vector2) -> void:
	pelota.position = destino - pelota.size / 2.0


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
