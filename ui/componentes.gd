class_name Componentes
extends RefCounted

## Las piezas que se repiten en toda la UI, en un solo lugar.
##
## Antes cada panel armaba sus filas, sus barras y sus etiquetas a mano, y
## por eso cambiar el aspecto de algo obligaba a tocar quince lugares (y
## siempre quedaba uno viejo). Acá viven las piezas y los paneles las piden.
##
## Todo devuelve Controls listos para meter en un contenedor: nada se
## engancha a estado global ni sabe de GameState.

## Anchos de las columnas del mercado. Viven acá y no en el panel porque el
## encabezado y las filas TIENEN que usar los mismos: cuando estaban
## duplicados, tocar uno y olvidarse del otro desalineaba la tabla entera.
## Calibrados para que la fila ENTERA entre en el ancho util de una
## pantalla de 1440 logicos menos el riel: 190+58+68+446+136+3x100, mas
## separaciones, da ~1.280. Si se agranda una columna hay que achicar otra.
const COL_NOMBRE := 190
const COL_EDAD := 58
const COL_POS := 68
const COL_MEDIA := 78
const COL_VALOR := 100
const COL_SALARIO := 96
const COL_CONTRATO := 96
const COL_ANIMO := 76
const COL_CLUB := 136
const COL_ACCION := 100

## Lo que ocupan juntas las columnas que tapa la niebla. Es el ancho del
## bloque "sin investigar" que las reemplaza — ver `bloque_tapado`.
const COL_TAPADAS := COL_MEDIA + COL_VALOR + COL_SALARIO + COL_CONTRATO + COL_ANIMO


## Una celda de ancho fijo. `alineacion` de HORIZONTAL_ALIGNMENT_*.
static func celda(texto: String, ancho: int, color: Color = Tema.TEXTO,
		alineacion: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.custom_minimum_size = Vector2(ancho, 0)
	l.horizontal_alignment = alineacion
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = texto
	l.add_theme_color_override("font_color", color)
	return l


## Una celda con un número: Archivo y cifras tabulares, para que las
## columnas no bailen al cambiar de fila.
static func celda_numero(texto: String, ancho: int, color: Color = Tema.TEXTO) -> Label:
	var l := celda(texto, ancho, color)
	var f := Tema.archivo(700)
	if f != null:
		l.add_theme_font_override("font", f)
	return l


## Una etiqueta chica y sólida: puesto, rasgo, habilidad.
static func chip(texto: String, fondo: Color, letra: Color = Tema.TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", letra)
	l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.corner_radius_top_left = 5
	caja.corner_radius_top_right = 5
	caja.corner_radius_bottom_left = 5
	caja.corner_radius_bottom_right = 5
	caja.content_margin_left = 8
	caja.content_margin_right = 8
	caja.content_margin_top = 3
	caja.content_margin_bottom = 3
	l.add_theme_stylebox_override("normal", caja)
	return l


## El bloque que reemplaza a los datos que todavía no conocés.
##
## Es el cambio central del rediseño del mercado: cinco "?" sueltos en una
## grilla no dicen nada —parecen datos rotos— mientras que un bloque
## atenuado que ocupa el lugar de todos se lee como "esto se compra
## investigando".
static func bloque_tapado(ancho: int) -> PanelContainer:
	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(ancho, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#14201b")
	estilo.border_width_top = 1
	estilo.border_width_bottom = 1
	estilo.border_width_left = 1
	estilo.border_width_right = 1
	estilo.border_color = Color("#35473e")
	estilo.corner_radius_top_left = 6
	estilo.corner_radius_top_right = 6
	estilo.corner_radius_bottom_left = 6
	estilo.corner_radius_bottom_right = 6
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	caja.add_theme_stylebox_override("panel", estilo)
	var l := Label.new()
	l.text = "Sin investigar"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color("#55655c"))
	l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	caja.add_child(l)
	return caja


## Lo mismo, pero con un informe EN CURSO: la barra y los días que faltan,
## en la fila misma. Antes había que ir a otra pestaña para saberlo.
static func bloque_investigando(ancho: int, progreso: float, dias: int) -> PanelContainer:
	var caja := bloque_tapado(ancho)
	var estilo: StyleBoxFlat = caja.get_theme_stylebox("panel")
	estilo.border_color = Color("#3d5340")
	caja.get_child(0).queue_free()

	var fila := HBoxContainer.new()
	caja.add_child(fila)
	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.value = progreso
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 6)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#2a3a33")
	fondo.corner_radius_top_left = 3
	fondo.corner_radius_top_right = 3
	fondo.corner_radius_bottom_left = 3
	fondo.corner_radius_bottom_right = 3
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Tema.AMBAR
	relleno.corner_radius_top_left = 3
	relleno.corner_radius_top_right = 3
	relleno.corner_radius_bottom_left = 3
	relleno.corner_radius_bottom_right = 3
	barra.add_theme_stylebox_override("fill", relleno)
	fila.add_child(barra)

	var l := Label.new()
	l.text = "%d %%  ·  faltan %d días" % [int(round(progreso * 100.0)), dias]
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Tema.AMBAR)
	l.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	fila.add_child(l)
	return caja


## Una barra de atributo con su techo: cuánto tiene y cuánto le queda por
## crecer. El color dice de un vistazo si es fuerte o flojo.
static func barra_atributo(nombre: String, valor: int, techo: int) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_child(celda(nombre.replace("_", " "), 130, Tema.SUAVE))

	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 100.0
	barra.value = valor
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 9)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#2a3a33")
	fondo.corner_radius_top_left = 5
	fondo.corner_radius_top_right = 5
	fondo.corner_radius_bottom_left = 5
	fondo.corner_radius_bottom_right = 5
	barra.add_theme_stylebox_override("background", fondo)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color_de_valor(valor)
	relleno.corner_radius_top_left = 5
	relleno.corner_radius_top_right = 5
	relleno.corner_radius_bottom_left = 5
	relleno.corner_radius_bottom_right = 5
	barra.add_theme_stylebox_override("fill", relleno)
	fila.add_child(barra)

	fila.add_child(celda_numero(str(valor), 42, Tema.TEXTO))
	# El techo de ESTE atributo: dos jugadores con el mismo potencial global
	# pueden tener techos muy distintos atributo por atributo.
	var margen := "→%d" % techo if techo > valor + 1 else "al tope"
	fila.add_child(celda(margen, 62, Tema.SUAVE))
	return fila


## El mismo criterio de color que ya usaba la ficha del jugador.
static func color_de_valor(valor: int) -> Color:
	if valor >= 75:
		return Tema.VERDE
	if valor >= 55:
		return Tema.VERDE_TIBIO
	if valor >= 40:
		return Tema.AMBAR
	return Tema.ROJO


## Una tarjeta con borde de acento al costado. `acento` transparente = sin
## barra, solo el panel.
static func tarjeta(acento: Color = Color.TRANSPARENT) -> PanelContainer:
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.PANEL
	estilo.corner_radius_top_left = Tema.RADIO
	estilo.corner_radius_top_right = Tema.RADIO
	estilo.corner_radius_bottom_left = Tema.RADIO
	estilo.corner_radius_bottom_right = Tema.RADIO
	estilo.content_margin_left = 16
	estilo.content_margin_right = 16
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	if acento != Color.TRANSPARENT:
		estilo.border_width_left = 4
		estilo.border_color = acento
	else:
		estilo.border_width_top = 1
		estilo.border_width_bottom = 1
		estilo.border_width_left = 1
		estilo.border_width_right = 1
		estilo.border_color = Tema.BORDE
	caja.add_theme_stylebox_override("panel", estilo)
	return caja


## Una fila de tabla: alto táctil y fondo alterno para poder seguirla con
## la vista a lo ancho de once columnas.
static func fila(par: bool) -> PanelContainer:
	var caja := PanelContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.PANEL if par else Color.TRANSPARENT
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	caja.add_theme_stylebox_override("panel", estilo)
	var dentro := HBoxContainer.new()
	dentro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Separacion chica: las celdas ya traen su propio aire y con la del tema
	# (8 px x once columnas) la fila se pasaba del ancho de la pantalla.
	dentro.add_theme_constant_override("separation", 4)
	caja.add_child(dentro)
	return caja


## El HBox de adentro de una fila, para meterle las celdas.
static func contenido(fila_panel: PanelContainer) -> HBoxContainer:
	return fila_panel.get_child(0)
