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
## Calibrados contra el ancho REAL disponible, medido: en 1152 logicos,
## despues del riel y del margen quedan 1.010 px. La suma de columnas
## (958) mas separaciones (28) y margenes (20) da 1.006 y entra justo.
## Si se agranda una columna hay que achicar otra, o el ultimo boton se
## sale de la pantalla — que es lo que pasaba con tres botones de accion
## de 130 en la misma fila: median 1.270.
const COL_NOMBRE := 160
const COL_EDAD := 46
const COL_POS := 56
const COL_MEDIA := 56
const COL_VALOR := 92
const COL_SALARIO := 84
const COL_CONTRATO := 58
const COL_ANIMO := 46
const COL_CLUB := 114
const COL_ACCION := 122
const COL_FICHAR := 110

## La tabla del mercado va en cuerpo chico: ver `celda`.
const TAM_TABLA := Tema.TAM_CHICO

## Anchos de la tabla de posiciones. Mismo criterio que el mercado: el
## encabezado y las filas los comparten para que no se desalineen.
const COL_POSICION := 46
const COL_EQUIPO := 236
const COL_JUGADOS := 50
const COL_GOLES := 56
const COL_DIFERENCIA := 62
const COL_PUNTOS := 64

## Lo que ocupan juntas las columnas que tapa la niebla. Es el ancho del
## bloque "sin investigar" que las reemplaza — ver `bloque_tapado`.
##
## Suma tambien las CUATRO separaciones que hay entre esas cinco celdas:
## el bloque es un solo hijo y no las lleva, asi que sin esto una fila
## destapada mide 16 px mas que una tapada y las dos no alinean.
const COL_TAPADAS := COL_MEDIA + COL_VALOR + COL_SALARIO + COL_CONTRATO + COL_ANIMO + 16


## Una celda de ancho fijo. `alineacion` de HORIZONTAL_ALIGNMENT_*.
## `tam` 0 = el del tema. La tabla del mercado pide TAM_CHICO: con once
## columnas, el cuerpo a 20 px obliga a anchos donde no entra ni un
## nombre ni un club, y un nombre recortado no sirve para nada.
static func celda(texto: String, ancho: int, color: Color = Tema.TEXTO,
		alineacion: int = HORIZONTAL_ALIGNMENT_LEFT, tam: int = 0) -> Label:
	var l := Label.new()
	if tam > 0:
		l.add_theme_font_size_override("font_size", tam)
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
## `alineacion` queda a la IZQUIERDA por defecto porque asi la usa el
## mercado, donde el encabezado son botones de ordenar alineados a la
## izquierda. La tabla de posiciones pide DERECHA a mano: en una columna
## de cifras de ancho distinto (9 y 32 puntos) alineadas a la izquierda
## las unidades no coinciden y hay que comparar digito por digito.
static func celda_numero(texto: String, ancho: int, color: Color = Tema.TEXTO,
		alineacion: int = HORIZONTAL_ALIGNMENT_LEFT, tam: int = 0) -> Label:
	var l := celda(texto, ancho, color, alineacion, tam)
	var f := Tema.archivo(700)
	if f != null:
		l.add_theme_font_override("font", f)
	return l


## Un botón que ocupa EXACTAMENTE el ancho de su columna, para las celdas
## que además se tocan: el encabezado que ordena y el nombre que abre la
## ficha.
##
## Un Button del tema trae 16 px de relleno de cada lado y su ancho mínimo
## incluye el del texto. Con eso el encabezado del mercado no respetaba
## ninguna columna: "Edad" en 46 px medía 74 y "Contrato" en 58 medía 101,
## y cada columna empujaba a la siguiente. Medido en 1152 lógicos, el
## título "Ánimo" terminaba 60 px a la derecha de su celda.
##
## Se le sacan las dos causas: relleno horizontal 0 en los cinco estados y
## `clip_text`, que deja el texto fuera del cálculo del mínimo.
static func boton_de_celda(texto: String, ancho: int,
		alineacion: int = HORIZONTAL_ALIGNMENT_LEFT, color: Color = Tema.TEXTO) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = texto
	b.flat = true
	b.alignment = alineacion
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(ancho, 0)
	b.add_theme_font_size_override("font_size", TAM_TABLA)
	b.add_theme_color_override("font_color", color)
	for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(estado, _caja_vacia())
	return b


## Un estilo sin nada: ni fondo ni relleno lateral. El vertical se
## conserva para que la fila no se achique respecto de las celdas.
static func _caja_vacia() -> StyleBoxEmpty:
	var e := StyleBoxEmpty.new()
	e.content_margin_left = 0
	e.content_margin_right = 0
	e.content_margin_top = Tema.PADDING_BOTON
	e.content_margin_bottom = Tema.PADDING_BOTON
	return e


## Un botón de acción de la tabla: ancho fijo y texto recortado.
## Sin recortar, "Vence pronto" mide 128 px en una columna de 122 y
## corre a la fila entera hacia la derecha.
static func boton_de_accion(texto: String, ancho: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 0)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_size_override("font_size", Tema.TAM_CHICO)
	return b


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
## `compacta` baja la letra un punto: es lo que usa la ficha entera, donde
## hay que meter 19 atributos (25 en un arquero) en una pantalla sin
## scroll. En la ficha lateral, que muestra cuatro, no hace falta.
static func barra_atributo(nombre: String, valor: int, techo: int,
		compacta: bool = false) -> HBoxContainer:
	var tam: int = Tema.TAM_CHICO if compacta else 0
	var fila := HBoxContainer.new()
	fila.add_child(celda(nombre.replace("_", " "), 96 if compacta else 130,
		Tema.SUAVE, HORIZONTAL_ALIGNMENT_LEFT, tam))

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

	fila.add_child(celda_numero(str(valor), 42, Tema.TEXTO,
		HORIZONTAL_ALIGNMENT_RIGHT if compacta else HORIZONTAL_ALIGNMENT_LEFT, tam))
	# El techo de ESTE atributo: dos jugadores con el mismo potencial global
	# pueden tener techos muy distintos atributo por atributo.
	var margen := "→%d" % techo if techo > valor + 1 else "al tope"
	fila.add_child(celda(margen, 54 if compacta else 62, Tema.SUAVE,
		HORIZONTAL_ALIGNMENT_LEFT, tam))
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


## Una barra de color fina al costado de una fila: la usa la tabla para
## marcar las zonas de ascenso y descenso. Va como columna propia y no
## como borde del panel porque el fondo alterno de la fila ya usa el
## StyleBox y dos bordes distintos se pisan.
static func acento_lateral(color: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(4, 0)
	var e := StyleBoxFlat.new()
	e.bg_color = color
	e.corner_radius_top_left = 2
	e.corner_radius_top_right = 2
	e.corner_radius_bottom_left = 2
	e.corner_radius_bottom_right = 2
	p.add_theme_stylebox_override("panel", e)
	return p


## El HBox de adentro de una fila, para meterle las celdas.
static func contenido(fila_panel: PanelContainer) -> HBoxContainer:
	return fila_panel.get_child(0)
