class_name CuboJugador
extends PanelContainer

## Un jugador en la cancha de la pantalla de Formación: puesto, nombre,
## media, energía y ánimo, y se puede arrastrar.
##
## Arrastrar uno sobre otro los INTERCAMBIA, esté el otro en la cancha o
## en el banco. Es la única forma de mover gente: antes había un botón
## "Subir a titular" en una pantalla y un intercambio a dos toques en
## otra, y ninguna de las dos dejaba ver dónde quedaba parado el equipo.
##
## El arrastre usa el sistema de Godot (_get_drag_data / _can_drop_data /
## _drop_data) en vez de seguir el mouse a mano: así funciona igual con el
## dedo, y el jugador ve la vista previa pegada al cursor.

signal intercambio_pedido(id_origen: int, id_destino: int)

const ANCHO := 104
const ALTO := 78

var jugador_id: int = -1
var _rol: String = ""
var _nombre: String = ""
var _media: float = 0.0
var _energia: float = 1.0
var _animo: float = 50.0
var _lesionado: bool = false
var _es_banco: bool = false


static func crear(jugador: Dictionary, rol: String, equipo: Team, es_banco: bool) -> CuboJugador:
	var c := CuboJugador.new()
	c.jugador_id = int(jugador["id"])
	c._rol = rol
	c._nombre = str(jugador.get("apellido", jugador.get("nombre", "?")))
	c._media = float(jugador["media"])
	c._energia = equipo.resistencia_pct(c.jugador_id)
	c._animo = float(equipo.animo.get(c.jugador_id, 50.0))
	c._lesionado = equipo.esta_lesionado(c.jugador_id)
	c._es_banco = es_banco
	c._armar()
	return c


func _armar() -> void:
	custom_minimum_size = Vector2(ANCHO, ALTO)
	size = Vector2(ANCHO, ALTO)
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
	var chip := Componentes.chip(_rol, Color("#4a2a28") if _lesionado else Color("#2f4a3c"))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arriba.add_child(chip)
	var media := Label.new()
	media.text = "%.1f" % _media
	media.mouse_filter = Control.MOUSE_FILTER_IGNORE
	media.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Tema.numero(media, Tema.TAM_CHICO)
	arriba.add_child(media)

	var nombre := Label.new()
	nombre.text = _nombre
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nombre.clip_text = true
	nombre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nombre.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja.add_child(nombre)

	# Energía y ánimo como dos barras finas: son los dos datos que hacen
	# falta al armar el equipo y no entran como números en 104 px.
	caja.add_child(_barrita(_energia, "Energía %d%%" % int(round(_energia * 100.0))))
	caja.add_child(_barrita(_animo / 100.0, "Ánimo %d" % int(_animo)))


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
	e.border_color = Tema.AMBAR if resaltado else (Tema.ROJO if _lesionado else Tema.BORDE)
	e.content_margin_left = 7
	e.content_margin_right = 7
	e.content_margin_top = 5
	e.content_margin_bottom = 5
	return e


func _get_drag_data(_pos: Vector2) -> Variant:
	# La vista previa es una copia chica: arrastrar el cubo mismo lo sacaría
	# de la cancha y el resto se reacomodaría a mitad del gesto.
	var vista := PanelContainer.new()
	vista.add_theme_stylebox_override("panel", _estilo(true))
	vista.modulate = Color(1, 1, 1, 0.85)
	var l := Label.new()
	l.text = "%s  %s" % [_rol, _nombre]
	vista.add_child(l)
	set_drag_preview(vista)
	add_theme_stylebox_override("panel", _estilo(true))
	return {"cubo_jugador_id": jugador_id}


func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
	return datos is Dictionary and datos.has("cubo_jugador_id") \
		and int(datos["cubo_jugador_id"]) != jugador_id


func _drop_data(_pos: Vector2, datos: Variant) -> void:
	intercambio_pedido.emit(int(datos["cubo_jugador_id"]), jugador_id)


func _notification(que: int) -> void:
	# Godot avisa cuando el arrastre termina, haya o no soltado en algo:
	# sin esto el cubo de origen se quedaba resaltado para siempre.
	if que == NOTIFICATION_DRAG_END:
		add_theme_stylebox_override("panel", _estilo())
