class_name CuboJugador
extends PanelContainer

## Un jugador en la cancha de la pantalla de Formación: puesto, nombre,
## media, energía y ánimo, y se puede arrastrar.
##
## Se cambia de lugar a dos jugadores en dos pasos: mantené apretado uno
## hasta que se marque (borde dorado y el simbolo de las dos flechas) y
## despues tocá al otro. Cambian al instante, esten donde esten: once,
## suplentes o reservas.
##
## Mantener apretado y no un toque simple: las listas de suplentes y
## reservas se scrollean con el dedo, y un toque que selecciona haria que
## cada scroll marcara a alguien sin querer. La espera separa las dos
## cosas sin pedir un boton aparte.
##
## Reemplaza al arrastre: arrastrar adentro de una lista que scrollea es
## el mismo gesto para dos acciones distintas, y en el celular ganaba
## siempre el scroll.

signal seleccion_pedida(jugador_id: int)

const ANCHO := 104
const ALTO := 78

## Cuanto hay que mantener apretado para marcar a un jugador.
const SEGUNDOS_PARA_MARCAR := 2.0

## Cuanto se puede mover el dedo sin que cuente como scroll. Mas que esto
## y la pulsacion se cancela: estabas scrolleando, no eligiendo.
const PIXELES_DE_TOLERANCIA := 12.0

var jugador_id: int = -1
var _rol: String = ""
var _nombre: String = ""
var _puesto_natural: String = ""
var _media: float = 0.0
var _energia: float = 1.0
var _animo: float = 50.0
## Por que no puede jugar, "" si puede (ver Alineacion.motivo). Antes acá
## habia un _lesionado y punto, asi que el suspendido se veia igual que
## uno sano: la unica forma de enterarte era el aviso previo al partido, y
## para entonces ya no estabas en la pantalla donde se cambia el once.
var _motivo: String = ""
var _motivo_corto: String = ""
var _motivo_largo: String = ""
var _es_banco: bool = false
## Marcado y esperando con quien cambiarse.
var _seleccionado: bool = false
## Mientras se mantiene apretado: cuanto lleva y desde donde.
var _apretando: float = -1.0
var _desde: Vector2 = Vector2.ZERO
## §8.4#4: lo que le cuesta el puesto que ocupa, 0 si esta en el suyo.
var _castigo_puesto: float = 0.0
## Cuanto se achica respecto del tamaño completo. La cancha la calcula
## segun el alto que le toco (ver CanchaFormacion._escala_cubos).
var escala: float = 1.0


static func crear(jugador: Dictionary, rol: String, equipo: Team, es_banco: bool,
		escala_inicial: float = 1.0) -> CuboJugador:
	var c := CuboJugador.new()
	c.jugador_id = int(jugador["id"])
	c._rol = rol
	c._puesto_natural = str(jugador.get("posicion", rol))
	c._nombre = str(jugador.get("apellido", jugador.get("nombre", "?")))
	c._media = float(jugador["media"])
	# La del PROXIMO partido, no la del ultimo: ver Team.energia_proximo_partido.
	c._energia = equipo.energia_proximo_partido(c.jugador_id)
	c._animo = float(equipo.animo.get(c.jugador_id, 50.0))
	c._motivo = Alineacion.motivo(equipo, c.jugador_id)
	c._motivo_corto = Alineacion.texto_motivo_corto(equipo, c.jugador_id)
	c._motivo_largo = Alineacion.texto_motivo(equipo, c.jugador_id)
	c._es_banco = es_banco
	c._castigo_puesto = 0.0 if es_banco else equipo.penalizacion_puesto(c.jugador_id)
	c.escala = escala_inicial
	c._armar()
	return c


func _armar() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO) * escala
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _estilo())

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 1)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caja)

	var arriba := HBoxContainer.new()
	arriba.add_theme_constant_override("separation", 4)
	arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(arriba)
	# El chip del puesto se pone rojo si el jugador NO es de ahi: es el
	# aviso de que ese cambio esta costando algo.
	var color_chip := Color("#4a2a28") if _motivo != "" else Color("#2f4a3c")
	if _castigo_puesto < 0.0:
		color_chip = Color("#4a3a28")
	if _seleccionado:
		# Las dos flechas dicen "este espera con quien cambiarse". El borde
		# dorado solo se confunde con cualquier otro resaltado.
		var marca := Label.new()
		marca.text = "⇄"
		marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marca.add_theme_font_size_override("font_size", int(Tema.TAM_CHICO * escala))
		marca.add_theme_color_override("font_color", Tema.AMBAR)
		arriba.add_child(marca)

	var chip := Componentes.chip(_rol, color_chip)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El chip trae tamaño fijo del componente y el resto del cubo escala:
	# con la cancha chica, un chip de tres letras (ARQ, MCO) se comia el
	# ancho y la media salia cortada ("42." en vez de "42.5").
	chip.add_theme_font_size_override("font_size", int(Tema.TAM_ETIQUETA * escala))
	# Y con menos aire a los costados: con los 8 px del componente, un
	# "ARQ" dejaba 30 px para la media y "42.5" no entraba.
	var caja_chip: StyleBoxFlat = chip.get_theme_stylebox("normal").duplicate()
	caja_chip.content_margin_left = 4
	caja_chip.content_margin_right = 4
	chip.add_theme_stylebox_override("normal", caja_chip)
	arriba.add_child(chip)
	var media := Label.new()
	media.text = "%.1f" % _media
	media.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Tema.numero(media, int(Tema.TAM_CHICO * escala))
	arriba.add_child(media)

	var nombre := Label.new()
	nombre.name = "nombre"
	nombre.text = _nombre
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.add_theme_font_size_override("font_size", int(Tema.TAM_CHICO * escala))
	caja.add_child(nombre)

	# Energía y ánimo como dos barras finas: son los dos datos que hacen
	# falta al armar el equipo y no entran como números en 104 px.
	caja.add_child(_barrita(_energia, "Energía %d%%" % int(round(_energia * 100.0))))
	caja.add_child(_barrita(_animo / 100.0, "Ánimo %d" % int(_animo)))

	# El motivo TAPA al castigo de puesto: los dos son la misma linea y el
	# cubo no tiene alto para dos. Al que no puede jugar no le importa
	# cuanto pierde fuera de su puesto, porque no va a jugar.
	if _motivo != "":
		var baja := Label.new()
		baja.text = _motivo_corto
		baja.mouse_filter = Control.MOUSE_FILTER_IGNORE
		baja.clip_text = true
		baja.add_theme_font_size_override("font_size", int(Tema.TAM_ETIQUETA * escala))
		baja.add_theme_color_override("font_color", Tema.ROJO)
		caja.add_child(baja)
	elif _castigo_puesto < 0.0:
		var aviso := Label.new()
		aviso.text = "%s  %.0f" % [_puesto_natural, _castigo_puesto]
		aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aviso.clip_text = true
		aviso.add_theme_font_size_override("font_size", int(Tema.TAM_ETIQUETA * escala))
		aviso.add_theme_color_override("font_color", Tema.AMBAR)
		aviso.tooltip_text = "Es %s, no %s: pierde %.0f puntos en todos sus duelos." % [
			_puesto_natural, _rol, absf(_castigo_puesto)]
		caja.add_child(aviso)

	# El tooltip repite el motivo entero: en el cubo entra "Susp. 2 f" y
	# nada mas, y las fechas exactas hacen falta para decidir.
	tooltip_text = _motivo_largo if _motivo != "" else ""


func _barrita(valor: float, ayuda: String) -> Control:
	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.value = clampf(valor, 0.0, 1.0)
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 5)
	barra.tooltip_text = ayuda
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#1a2420")
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Componentes.color_de_valor(int(round(clampf(valor, 0.0, 1.0) * 100.0)))
	barra.add_theme_stylebox_override("fill", relleno)
	return barra


func _estilo(resaltado: bool = false) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Tema.PANEL_ALTO if not _es_banco else Tema.PANEL
	e.corner_radius_top_left = 8
	e.corner_radius_top_right = 8
	e.corner_radius_bottom_left = 8
	e.corner_radius_bottom_right = 8
	e.border_width_top = 2
	e.border_width_bottom = 2
	e.border_width_left = 2
	e.border_width_right = 2
	e.border_color = Tema.AMBAR if resaltado else (Tema.ROJO if _motivo != "" else Tema.BORDE)
	e.content_margin_left = 7
	e.content_margin_right = 7
	e.content_margin_top = 5
	e.content_margin_bottom = 5
	return e


## Mantener apretado marca; soltar antes, o moverse mas que la
## tolerancia, no hace nada. El toque simple sobre un cubo cuando YA hay
## otro marcado lo maneja main.gd: ahi el segundo toque cierra el cambio.
func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_apretando = 0.0
			_desde = evento.global_position
			_pintar()
		else:
			# Soltar antes de tiempo con OTRO ya marcado cierra el cambio:
			# el segundo jugador se elige de un toque, que es lo rapido.
			var completo: bool = _apretando < 0.0
			_apretando = -1.0
			_pintar()
			if not completo:
				seleccion_pedida.emit(jugador_id)
	elif evento is InputEventMouseMotion and _apretando >= 0.0:
		if evento.global_position.distance_to(_desde) > PIXELES_DE_TOLERANCIA:
			# Se movio: estaba scrolleando la lista.
			_apretando = -1.0
			_pintar()


func _process(delta: float) -> void:
	if _apretando < 0.0:
		return
	_apretando += delta
	if _apretando >= SEGUNDOS_PARA_MARCAR:
		# -1 marca que la pulsacion ya se cumplio: al soltar no dispara el
		# toque simple otra vez.
		_apretando = -1.0
		seleccion_pedida.emit(jugador_id)
	queue_redraw()


## El aro que se va llenando mientras mantenes apretado. Va en _draw del
## panel, o sea DEBAJO de los textos, asi que se dibuja en la esquina de
## arriba a la izquierda, que es la unica que queda libre.
func _draw() -> void:
	if _apretando < 0.0:
		return
	var avance: float = clampf(_apretando / SEGUNDOS_PARA_MARCAR, 0.0, 1.0)
	var radio: float = 9.0 * escala
	var centro := Vector2(radio + 2.0, radio + 2.0)
	draw_arc(centro, radio, 0.0, TAU, 24, Color(1, 1, 1, 0.15), 2.0)
	draw_arc(centro, radio, -PI * 0.5, -PI * 0.5 + TAU * avance, 24, Tema.AMBAR, 3.0)


## Marcado o no. Lo decide la pantalla, no el cubo: el que estaba marcado
## se apaga cuando se marca otro.
func marcar_seleccionado(valor: bool) -> void:
	if _seleccionado == valor:
		return
	_seleccionado = valor
	_rearmar()
	_pintar()


func _pintar() -> void:
	add_theme_stylebox_override("panel", _estilo(_seleccionado or _apretando >= 0.0))


## Rearma el cubo a otra escala. La cancha lo llama cuando cambia de
## tamaño; el texto se achica con el cubo, si no se sale por los costados.
func aplicar_escala(nueva: float) -> void:
	escala = nueva
	_rearmar()
	_pintar()


## Vuelve a armar el contenido del cubo. remove_child ANTES del
## queue_free: el cubo se rearma tambien cuando todavia no entro al
## arbol (la cancha lo marca recien creado), y ahi queue_free no llega a
## sacar a nadie antes de que _armar agregue los hijos nuevos — quedaban
## dos chips y dos nombres encimados.
func _rearmar() -> void:
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	_armar()
