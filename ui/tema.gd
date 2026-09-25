class_name Tema
extends RefCounted

## El sistema visual del juego, en un solo lugar.
##
## Antes cada panel armaba sus botones y sus colores a mano, con hexadecimales
## sueltos repartidos por ui/main.gd: cambiar un color era tocar quince
## lugares y siempre quedaba uno viejo. Acá viven la paleta, la tipografía y
## los estilos, y la UI los hereda desde la raíz.
##
## Se construye en código y no como un .tres a propósito: así se lee en el
## diff de git, que es donde se revisa todo lo demás de este proyecto.
##
## Todo lo que hay acá es implementable con StyleBoxFlat: color de fondo,
## borde, radio y márgenes. Sin degradados ni imágenes.

# --- Paleta ----------------------------------------------------------------
# Dos fondos seleccionables: negro carbón o crema/verde claro. Comparten los
# cuatro acentos del juego: amarillo decide, verde mejora, coral alerta y
# turquesa invita a explorar.
static var FONDO := Color("#101512")
static var PANEL := Color("#242a26")
static var PANEL_ALTO := Color("#303732")
static var BORDE := Color("#5d685f")
static var TEXTO := Color("#fff8df")
static var SUAVE := Color("#aeb9b2")
static var RIEL := Color("#111816")
static var BARRA := Color("#171d19")
static var BORDE_RIEL := Color("#ffcf43")

static var AMBAR := Color("#ffcf43")
static var VERDE := Color("#4fc875")
static var ROJO := Color("#ff6b57")
static var CELESTE := Color("#53c7c1")
const TINTA_OSCURA := Color("#101512")

## Verde intermedio para las barras de atributo (ya existía en la ficha).
static var VERDE_TIBIO := Color("#91d06e")


## Cambia la paleta antes de construir la interfaz. Los nodos con colores
## propios tambien leen estas variables, por eso el cambio de tema recarga
## solamente la escena de UI y conserva la partida que vive en GameState.
static func aplicar_modo(modo: String) -> void:
	if modo == "claro":
		FONDO = Color("#dff0bf")
		PANEL = Color("#fff8df")
		PANEL_ALTO = Color("#e9f4cf")
		BORDE = Color("#496a56")
		TEXTO = Color("#203e37")
		SUAVE = Color("#61766c")
		RIEL = Color("#42b7b2")
		BARRA = Color("#fff9e7")
		BORDE_RIEL = Color("#294e4a")
	else:
		FONDO = Color("#101512")
		PANEL = Color("#242a26")
		PANEL_ALTO = Color("#303732")
		BORDE = Color("#5d685f")
		TEXTO = Color("#fff8df")
		SUAVE = Color("#aeb9b2")
		RIEL = Color("#111816")
		BARRA = Color("#171d19")
		BORDE_RIEL = Color("#ffcf43")

# --- Tipografía ------------------------------------------------------------
const RUTA_ARCHIVO := "res://ui/fuentes/Archivo.ttf"
const RUTA_BARLOW := "res://ui/fuentes/Barlow-Regular.ttf"
const RUTA_BARLOW_MEDIA := "res://ui/fuentes/Barlow-Medium.ttf"
const RUTA_BARLOW_SEMI := "res://ui/fuentes/Barlow-SemiBold.ttf"

## Barlow para leer, Archivo para números y títulos. Archivo es una fuente
## VARIABLE: un solo archivo da todos los pesos vía FontVariation.
const TAM_BASE := 20
const TAM_CHICO := 16
const TAM_ETIQUETA := 14

# --- Medidas ---------------------------------------------------------------
## Alto mínimo de algo que se toca con el dedo. 52 px lógicos son ~8,6 mm en
## una pantalla de 320 dpi: por debajo de eso hay que apuntar.
const ALTO_TACTIL := 52
const RADIO := 4
const RADIO_MODAL := 7
const PADDING_BOTON := 12
## Aire uniforme entre la interfaz principal y los cuatro bordes de pantalla.
const MARGEN_PANTALLA := 16


static func _fuente(ruta: String) -> FontFile:
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta)


## Archivo con un peso concreto. La fuente es variable, así que el peso se
## pide por variación en vez de cargar un archivo por peso.
static func archivo(peso: int = 700) -> FontVariation:
	var base := _fuente(RUTA_ARCHIVO)
	if base == null:
		return null
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": peso}
	return v


## Barlow SemiBold suelta, para resaltar una linea de texto corrida sin
## cambiarle el tamano ni el color.
static func negrita() -> FontFile:
	return _fuente(RUTA_BARLOW_SEMI)


static func _caja(fondo: Color, borde: Color = Color.TRANSPARENT, grosor: int = 0) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = fondo
	caja.corner_radius_top_left = RADIO
	caja.corner_radius_top_right = RADIO
	caja.corner_radius_bottom_left = RADIO
	caja.corner_radius_bottom_right = RADIO
	caja.content_margin_top = PADDING_BOTON
	caja.content_margin_bottom = PADDING_BOTON
	caja.content_margin_left = 16
	caja.content_margin_right = 16
	if grosor > 0:
		caja.border_width_top = grosor
		caja.border_width_bottom = grosor
		caja.border_width_left = grosor
		caja.border_width_right = grosor
		caja.border_color = borde
		caja.shadow_color = Color("#070907")
		caja.shadow_size = 2
		caja.shadow_offset = Vector2(2, 2)
	return caja


## Construye el tema entero. Se aplica en la RAÍZ y de ahí lo hereda todo,
## incluida la UI que se crea después: los paneles se reconstruyen solos todo
## el tiempo y un tema en la raíz no se puede olvidar en una pantalla nueva.
static func construir() -> Theme:
	var tema := Theme.new()

	# La interfaz se lee en pantalla chica: el peso regular se perdia sobre
	# la trama. La presentacion usa trazos firmes; toda la UI parte de semibold.
	var cuerpo := _fuente(RUTA_BARLOW_SEMI)
	if cuerpo != null:
		tema.default_font = cuerpo
	tema.default_font_size = TAM_BASE

	var semi := _fuente(RUTA_BARLOW_SEMI)

	# --- Botones -----------------------------------------------------------
	# Tres jerarquías, y una sola ámbar por pantalla: si todo resalta, nada
	# resalta. La ámbar se pide a mano con `primario()`.
	tema.set_stylebox("normal", "Button", _caja(PANEL_ALTO, BORDE, 2))
	tema.set_stylebox("hover", "Button", _caja(PANEL_ALTO.lightened(0.08), AMBAR, 2))
	tema.set_stylebox("pressed", "Button", _caja(PANEL, AMBAR, 2))
	tema.set_stylebox("disabled", "Button", _caja(PANEL, BORDE.darkened(0.20), 2))
	tema.set_stylebox("focus", "Button", _caja(Color.TRANSPARENT, AMBAR, 2))
	tema.set_color("font_color", "Button", TEXTO)
	tema.set_color("font_hover_color", "Button", TEXTO)
	tema.set_color("font_pressed_color", "Button", AMBAR)
	tema.set_color("font_disabled_color", "Button", SUAVE.darkened(0.25))
	if semi != null:
		tema.set_font("font", "Button", semi)
	tema.set_constant("h_separation", "Button", 8)

	for tipo in ["OptionButton", "MenuButton", "CheckBox", "CheckButton"]:
		for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
			tema.set_stylebox(estado, tipo, tema.get_stylebox(estado, "Button"))
		tema.set_color("font_color", tipo, TEXTO)
		tema.set_color("font_disabled_color", tipo, SUAVE.darkened(0.25))
		if semi != null:
			tema.set_font("font", tipo, semi)

	# --- Campos ------------------------------------------------------------
	var campo := _caja(FONDO, BORDE, 2)
	tema.set_stylebox("normal", "LineEdit", campo)
	tema.set_stylebox("focus", "LineEdit", _caja(FONDO, AMBAR, 2))
	tema.set_color("font_color", "LineEdit", TEXTO)
	tema.set_color("caret_color", "LineEdit", AMBAR)
	tema.set_stylebox("panel", "PopupMenu", _caja(PANEL, BORDE, 1))
	tema.set_color("font_color", "PopupMenu", TEXTO)
	tema.set_color("font_hover_color", "PopupMenu", AMBAR)

	# --- Texto -------------------------------------------------------------
	tema.set_color("font_color", "Label", TEXTO)
	tema.set_color("default_color", "RichTextLabel", TEXTO)
	# Aire entre renglones: en las listas del plantel se TOCAN nombres, no
	# solo se leen.
	tema.set_constant("line_separation", "RichTextLabel", 8)
	tema.set_constant("line_spacing", "Label", 6)

	# --- Superficies -------------------------------------------------------
	var panel := _caja(PANEL, BORDE, 2)
	tema.set_stylebox("panel", "PanelContainer", panel)
	tema.set_stylebox("panel", "Panel", panel)

	# Los dialogos son una capa propia, no otro rectangulo de la pantalla.
	# El borde expandido tambien pinta la barra de titulo de las ventanas
	# embebidas: sin esto Godot dejaba arriba una franja gris desconectada.
	var borde_dialogo := _caja(PANEL_ALTO, AMBAR.darkened(0.22), 3)
	borde_dialogo.corner_radius_top_left = RADIO_MODAL
	borde_dialogo.corner_radius_top_right = RADIO_MODAL
	borde_dialogo.corner_radius_bottom_left = RADIO_MODAL
	borde_dialogo.corner_radius_bottom_right = RADIO_MODAL
	borde_dialogo.expand_margin_left = 2
	borde_dialogo.expand_margin_right = 2
	borde_dialogo.expand_margin_top = 48
	borde_dialogo.expand_margin_bottom = 2
	borde_dialogo.shadow_color = Color(0, 0, 0, 0.55)
	borde_dialogo.shadow_size = 18
	borde_dialogo.shadow_offset = Vector2(0, 8)
	tema.set_stylebox("embedded_border", "Window", borde_dialogo)
	tema.set_stylebox("embedded_unfocused_border", "Window", borde_dialogo)
	tema.set_color("title_color", "Window", TEXTO)
	tema.set_constant("title_height", "Window", 48)
	tema.set_constant("title_font_size", "Window", TAM_BASE)
	if semi != null:
		tema.set_font("title_font", "Window", semi)

	var cuerpo_dialogo := _caja(PANEL, Color.TRANSPARENT)
	cuerpo_dialogo.corner_radius_top_left = 0
	cuerpo_dialogo.corner_radius_top_right = 0
	cuerpo_dialogo.corner_radius_bottom_left = RADIO_MODAL
	cuerpo_dialogo.corner_radius_bottom_right = RADIO_MODAL
	cuerpo_dialogo.content_margin_left = 24
	cuerpo_dialogo.content_margin_right = 24
	cuerpo_dialogo.content_margin_top = 22
	cuerpo_dialogo.content_margin_bottom = 22
	tema.set_stylebox("panel", "AcceptDialog", cuerpo_dialogo)
	tema.set_stylebox("panel", "ConfirmationDialog", cuerpo_dialogo)
	for tipo_dialogo in ["AcceptDialog", "ConfirmationDialog"]:
		tema.set_constant("buttons_min_height", tipo_dialogo, ALTO_TACTIL)
		tema.set_constant("buttons_min_width", tipo_dialogo, 120)
		tema.set_constant("buttons_separation", tipo_dialogo, 18)

	var fondo_scroll := StyleBoxFlat.new()
	fondo_scroll.bg_color = Color.TRANSPARENT
	tema.set_stylebox("panel", "ScrollContainer", fondo_scroll)

	tema.set_constant("separation", "VBoxContainer", 8)
	tema.set_constant("separation", "HBoxContainer", 8)
	tema.set_constant("h_separation", "GridContainer", 4)
	tema.set_constant("v_separation", "GridContainer", 4)

	return tema


## Termina de vestir un dialogo una vez creados sus botones internos.
## `confirmar` marca la accion que cambia estado; un simple "Cerrar" queda
## neutro para no competir visualmente con el contenido.
static func dialogo(ventana: AcceptDialog, confirmar: bool = false) -> AcceptDialog:
	ventana.transparent = true
	ventana.dialog_autowrap = true
	ventana.add_theme_constant_override("buttons_min_height", ALTO_TACTIL)
	ventana.add_theme_constant_override("buttons_min_width", 120)
	ventana.add_theme_constant_override("buttons_separation", 18)
	var etiqueta := ventana.get_label()
	etiqueta.add_theme_color_override("font_color", TEXTO)
	etiqueta.add_theme_constant_override("line_spacing", 8)
	# La X es demasiado chica para celular. Todo dialogo conserva una salida
	# textual grande en la fila inferior, aun cuando tambien tenga acciones.
	if ventana is ConfirmationDialog:
		var confirmacion := ventana as ConfirmationDialog
		confirmacion.cancel_button_text = "Cerrar"
	else:
		ventana.ok_button_text = "Cerrar"
	if confirmar:
		primario(ventana.get_ok_button())
	return ventana


## La acción principal de una pantalla: ámbar, y una sola por pantalla.
static func primario(boton: Button) -> Button:
	var caja := _caja(AMBAR, AMBAR.lightened(0.28), 2)
	boton.add_theme_stylebox_override("normal", caja)
	boton.add_theme_stylebox_override("hover", _caja(AMBAR.lightened(0.08), TEXTO, 2))
	boton.add_theme_stylebox_override("pressed", _caja(AMBAR.darkened(0.12), FONDO, 2))
	boton.add_theme_stylebox_override("disabled", _caja(AMBAR.darkened(0.45), BORDE, 2))
	boton.add_theme_color_override("font_color", TINTA_OSCURA)
	boton.add_theme_color_override("font_hover_color", TINTA_OSCURA)
	boton.add_theme_color_override("font_pressed_color", TINTA_OSCURA)
	var titulo := archivo(700)
	if titulo != null:
		boton.add_theme_font_override("font", titulo)
	boton.custom_minimum_size.y = ALTO_TACTIL
	return boton


## Accion irreversible. Mantiene la misma jerarquia que la primaria, pero
## el rojo deja claro que no es una confirmacion cotidiana.
static func peligro(boton: Button) -> Button:
	boton.add_theme_stylebox_override("normal", _caja(ROJO, ROJO.lightened(0.25), 2))
	boton.add_theme_stylebox_override("hover", _caja(ROJO.lightened(0.08), TEXTO, 2))
	boton.add_theme_stylebox_override("pressed", _caja(ROJO.darkened(0.12), FONDO, 2))
	boton.add_theme_stylebox_override("disabled", _caja(ROJO.darkened(0.45), BORDE, 2))
	for estado in ["font_color", "font_hover_color", "font_pressed_color"]:
		boton.add_theme_color_override(estado, TEXTO)
	var titulo := archivo(700)
	if titulo != null:
		boton.add_theme_font_override("font", titulo)
	boton.custom_minimum_size.y = ALTO_TACTIL
	return boton


## Marca un botón como la sección/solapa ABIERTA. No se usa `disabled` para
## eso: gris apagado se lee como "no se puede tocar", que es lo contrario de
## "estás acá". Va fondo claro y una barra ámbar al costado.
static func seleccionado(boton: Button, activo: bool) -> Button:
	if not activo:
		if boton.has_meta("boton_riel"):
			return boton_riel(boton)
		for estado in ["normal", "hover", "pressed"]:
			boton.remove_theme_stylebox_override(estado)
		for color_estado in ["font_color", "font_hover_color", "font_pressed_color"]:
			boton.remove_theme_color_override(color_estado)
		return boton
	var caja := _caja(AMBAR, AMBAR.lightened(0.30), 2)
	for estado in ["normal", "hover", "pressed"]:
		boton.add_theme_stylebox_override(estado, caja)
	boton.add_theme_color_override("font_color", TINTA_OSCURA)
	boton.add_theme_color_override("font_hover_color", TINTA_OSCURA)
	boton.add_theme_color_override("font_pressed_color", TINTA_OSCURA)
	return boton


## Boton lateral inactivo: sin una caja repetida alrededor. La seleccion
## amarilla aparece recien al entrar, igual que en la propuesta HTML.
static func boton_riel(boton: Button) -> Button:
	boton.set_meta("boton_riel", true)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := _caja(PANEL_ALTO, BORDE, 1)
	var pressed := _caja(PANEL, AMBAR, 1)
	boton.add_theme_stylebox_override("normal", normal)
	boton.add_theme_stylebox_override("hover", hover)
	boton.add_theme_stylebox_override("pressed", pressed)
	boton.add_theme_color_override("font_color", TEXTO)
	boton.add_theme_color_override("font_hover_color", TEXTO)
	boton.add_theme_color_override("font_pressed_color", AMBAR)
	return boton


## Un número que se lee de un vistazo: Archivo, con cifras tabulares para
## que las columnas de la tabla no bailen.
static func numero(etiqueta: Label, tam: int = TAM_BASE,
		color: Color = Color.TRANSPARENT) -> Label:
	if color == Color.TRANSPARENT:
		color = TEXTO
	var f := archivo(700)
	if f != null:
		etiqueta.add_theme_font_override("font", f)
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", color)
	return etiqueta


## Contraste extra para texto apoyado sobre superficies de color intenso.
static func sombra_texto(etiqueta: Label) -> Label:
	etiqueta.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	etiqueta.add_theme_constant_override("shadow_offset_x", 2)
	etiqueta.add_theme_constant_override("shadow_offset_y", 2)
	return etiqueta


## Encabezado de sección: chico, espaciado y apagado.
static func etiqueta_seccion(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.add_theme_font_size_override("font_size", TAM_ETIQUETA)
	l.add_theme_color_override("font_color", ROJO)
	var f := archivo(700)
	if f != null:
		l.add_theme_font_override("font", f)
	return l
